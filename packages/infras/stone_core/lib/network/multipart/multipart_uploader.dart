/// 分片上传引擎（dio PUT 预签名 URL）。
///
/// 行为规格来源（legacy）：`appunits/file_transfer/lib_old/src/service/oss_client.dart`
/// —— 分片切割 / Semaphore 并发 / 进度节流 / 重试 / 断点续传 / 去重排序 /
/// 完整性校验的编排语义逐项保真；legacy 的分片 PUT 走原生 C++ 通道
/// （L1508 `NetworkTools.httpUpload`），本引擎将传输通道替换为 dio。
///
/// 与业务协议解耦：分片会话（initiate/complete/abort）、凭证获取与断点
/// 状态持久化均由调用方负责，经 [PartUrlProvider] 与 `uploadedParts` 注入。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import '../../logger/logger_core.dart';
import '../result.dart';

import 'multipart_upload_models.dart';

const String _tag = 'Net';

/// 分片几何信息（legacy: oss_client.dart `_UploadPart` L25-37）。
class _PartSlice {
  const _PartSlice(this.partNumber, this.offset, this.end);

  final int partNumber;
  final int offset;
  final int end;

  int get size => end - offset;
}

/// 信号量 —— 语义逐字移植自 legacy `Semaphore`（L40-79）：
/// [acquire] 返回 `Future<bool>`，[cancelAll] 后等待者静默拿到 false 而非异常。
class _Semaphore {
  _Semaphore(this._count);

  int _count;
  final Queue<Completer<bool>> _waitQueue = Queue<Completer<bool>>();
  bool _cancelled = false;

  Future<bool> acquire() async {
    if (_cancelled) return false;
    if (_count > 0) {
      _count--;
      return true;
    }
    final completer = Completer<bool>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty && !_cancelled) {
      _waitQueue.removeFirst().complete(true);
    } else if (!_cancelled) {
      _count++;
    }
  }

  void cancelAll() {
    _cancelled = true;
    while (_waitQueue.isNotEmpty) {
      _waitQueue.removeFirst().complete(false);
    }
    _count = 0;
  }
}

/// 进度聚合器（legacy: `_ProgressTracker` L81-173）。
///
/// 聚合各分片在途字节 + 断点续传初始字节，按 [interval] 节流发射；
/// progress clamp [0,1]，速度含 NaN/Inf/负值防御；dispose 幂等。
class _ProgressAggregator {
  _ProgressAggregator({
    required this.taskId,
    required this.totalBytes,
    required this.initialBytes,
    required this.interval,
    required this.sink,
  }) : _lastEmitAt = DateTime.now(),
       _lastTotal = initialBytes;

  final String taskId;
  final int totalBytes;
  final int initialBytes;
  final Duration interval;
  final void Function(MultipartProgress) sink;

  final Map<int, int> _partBytes = {};
  DateTime _lastEmitAt;
  int _lastTotal;
  bool _disposed = false;

  void update(int partNumber, int bytes) {
    if (_disposed) return;
    _partBytes[partNumber] = bytes;
    _emit(force: false);
  }

  void complete(int partNumber, int size) {
    if (_disposed) return;
    _partBytes[partNumber] = size;
    _emit(force: false);
  }

  /// 收尾强制发射（保证 progress == 1.0 必达）。
  void finish() => _emit(force: true);

  void _emit({required bool force}) {
    if (_disposed) return;

    var sent = initialBytes;
    for (final bytes in _partBytes.values) {
      sent += bytes;
    }

    // 空文件视为已完成（legacy 对 0 字节文件产生 0 个分片直接收尾）。
    final progress = totalBytes > 0 ? (sent / totalBytes).clamp(0.0, 1.0) : 1.0;

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastEmitAt).inMilliseconds;

    // 速度防御：NaN / Infinity / 负值一律归零（legacy L137-143）。
    var speed = 0.0;
    if (elapsedMs > 0) {
      speed = (sent - _lastTotal) * 1000 / elapsedMs;
      if (speed.isNaN || speed.isInfinite || speed < 0) speed = 0;
    }

    // 节流：超过间隔或已完成才发射（legacy L145-147）。
    if (!force && elapsedMs <= interval.inMilliseconds && progress < 1.0) {
      return;
    }

    sink(
      MultipartProgress(
        taskId: taskId,
        bytesSent: sent,
        totalBytes: totalBytes,
        progress: progress,
        bytesPerSecond: speed.toInt(),
      ),
    );
    _lastEmitAt = now;
    _lastTotal = sent;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _partBytes.clear();
  }
}

/// 通用分片上传器。
///
/// 刻意不复用 `HttpManager` 的全局 Dio：其拦截器链中
/// `LogInterceptor(requestBody: true)` 会打印二进制分片体，
/// refresh-login 拦截器可能中断长时间 PUT。默认自建裸 Dio，
/// 测试经构造注入 mock。
class MultipartUploader {
  /// Creates an uploader backed by [dio], or a bare instance when omitted.
  MultipartUploader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;

  final Map<String, StreamController<MultipartProgress>> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};
  bool _disposed = false;

  /// 任务进度流（broadcast，高频消费方各自订阅；
  /// 对齐 file_transfer `oss_data_source.watchProgress` 的消费约定）。
  ///
  /// 任务结束（成功/失败）后对应流即关闭；重新上传同一 taskId 需重新订阅。
  Stream<MultipartProgress> watchProgress(String taskId) {
    if (_disposed) {
      throw StateError('MultipartUploader has been disposed');
    }
    return _controllerFor(taskId).stream;
  }

  /// 取消指定任务（legacy: `cancelUploadByTaskId` L978 的 per-task 语义）。
  void cancel(String taskId) {
    _cancelTokens[taskId]?.cancel('cancelled by caller');
  }

  /// 释放全部资源；自建的 Dio 一并关闭。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('uploader disposed');
    }
    _cancelTokens.clear();
    for (final controller in _progress.values) {
      unawaited(controller.close());
    }
    _progress.clear();
    if (_ownsDio) _dio.close(force: true);
  }

  /// 分片上传 [filePath]，每片目标经 [partUrl] 注入。
  ///
  /// [uploadedParts]：断点续传注入的历史分片（partNumber → eTag），
  /// 引擎跳过这些分片（legacy L562）并把它们合并进最终结果。
  /// 越界分片号（> 总分片数）会被忽略。
  ///
  /// 成功返回按 partNumber 升序、经去重与完整性校验的全部分片；
  /// 任一分片耗尽重试即快速失败（legacy `eagerError` L911），
  /// 其余在途分片被取消、等待者静默退出。
  Future<Result<MultipartUploadResult>> uploadFile({
    required String taskId,
    required String filePath,
    required PartUrlProvider partUrl,
    Map<int, String> uploadedParts = const {},
    MultipartUploadConfig config = const MultipartUploadConfig(),
    CancelToken? cancelToken,
  }) async {
    // use-after-dispose 防御：自建 Dio 已关闭，继续使用只会得到晦涩的运行时错误。
    if (_disposed) {
      return Result.failure(
        Failure.input(message: 'MultipartUploader has been disposed'),
      );
    }
    // 同 taskId 并发防御：否则 cancel/进度流会在两个物理任务间串流。
    if (_cancelTokens.containsKey(taskId)) {
      return Result.failure(
        Failure.input(message: 'Upload already in progress for task: $taskId'),
      );
    }

    // 单次 stat 同时完成存在性与大小获取，消除 exists/length 之间的 TOCTOU
    // 窗口（stat 对不存在的路径返回 notFound 而非抛异常）。
    final file = File(filePath);
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file) {
      return Result.failure(
        Failure.input(message: 'file not existed: $filePath'),
      );
    }

    final fileSize = stat.size;
    final totalParts = (fileSize / config.partSize).ceil();

    // 分片切割：offset = (n-1)*partSize，尾片截断（legacy L560-575）。
    final resumed = <MultipartPartResult>[];
    final pending = <_PartSlice>[];
    for (var n = 1; n <= totalParts; n++) {
      final offset = (n - 1) * config.partSize;
      final end = math.min(offset + config.partSize, fileSize);
      final eTag = uploadedParts[n];
      if (eTag != null) {
        resumed.add(
          MultipartPartResult(partNumber: n, eTag: eTag, size: end - offset),
        );
      } else {
        pending.add(_PartSlice(n, offset, end));
      }
    }

    final initialBytes = resumed.fold<int>(0, (sum, p) => sum + p.size);
    final token = cancelToken ?? CancelToken();
    _cancelTokens[taskId] = token;

    final aggregator = _ProgressAggregator(
      taskId: taskId,
      totalBytes: fileSize,
      initialBytes: initialBytes,
      interval: config.progressInterval,
      sink: _controllerFor(taskId).add,
    );
    final semaphore = _Semaphore(config.maxConcurrent);

    StoneLogger.info(
      '[multipart] $taskId start: total=$totalParts '
      'resumed=${resumed.length} pending=${pending.length}',
      _tag,
    );

    try {
      final tasks = pending
          .map(
            (part) => _uploadPartGuarded(
              part: part,
              file: file,
              partUrl: partUrl,
              config: config,
              token: token,
              semaphore: semaphore,
              aggregator: aggregator,
            ),
          )
          .toList();

      // 一片终败立即失败并取消其余（legacy L911 eagerError + L920-926）。
      final results = await Future.wait(tasks, eagerError: true);

      final merged = <MultipartPartResult>[...resumed];
      for (final result in results) {
        if (result != null) merged.add(result);
      }

      // 去重（保留最后，legacy L605-628）→ 排序（L630）→ 缺片即失败（L633-637）。
      final unique = <int, MultipartPartResult>{};
      for (final part in merged) {
        if (unique.containsKey(part.partNumber)) {
          StoneLogger.warning(
            '[multipart] $taskId duplicate part ${part.partNumber}, '
            'keeping the latest',
            _tag,
          );
        }
        unique[part.partNumber] = part;
      }
      final parts = unique.values.toList()
        ..sort((a, b) => a.partNumber.compareTo(b.partNumber));

      if (parts.length != totalParts) {
        return Result.failure(
          Failure(
            code: 'ERR_MISSING_PARTS',
            message: 'Missing parts: expected $totalParts, got ${parts.length}',
            type: FailureType.data,
          ),
        );
      }

      aggregator.finish();
      StoneLogger.info(
        '[multipart] $taskId all $totalParts parts uploaded',
        _tag,
      );
      return Result.success(
        MultipartUploadResult(parts: parts, totalBytes: fileSize),
      );
    } catch (error) {
      // 静默取消等待者 + 取消在途分片（legacy L923-926）。
      semaphore.cancelAll();
      if (!token.isCancelled) token.cancel('sibling part failed');
      final failure = _toFailure(error);
      StoneLogger.error('[multipart] $taskId failed: $failure', _tag);
      return Result.failure(failure);
    } finally {
      aggregator.dispose();
      _cancelTokens.remove(taskId);
      // 任务级进度流收尾：否则长驻实例下 _progress 随唯一 taskId 数量
      // 只增不减（泄漏）。最后一个快照已由 aggregator 发射，随后流结束。
      final controller = _progress.remove(taskId);
      if (controller != null && !controller.isClosed) {
        unawaited(controller.close());
      }
    }
  }

  /// 单分片：acquire 一次 → 重试循环 → finally release（legacy L715-908）。
  Future<MultipartPartResult?> _uploadPartGuarded({
    required _PartSlice part,
    required File file,
    required PartUrlProvider partUrl,
    required MultipartUploadConfig config,
    required CancelToken token,
    required _Semaphore semaphore,
    required _ProgressAggregator aggregator,
  }) async {
    final acquired = await semaphore.acquire();
    // 静默退出：cancelAll 后不抛异常（legacy L718-721）。
    if (!acquired) return null;
    try {
      return await _uploadPartWithRetry(
        part: part,
        file: file,
        partUrl: partUrl,
        config: config,
        token: token,
        aggregator: aggregator,
      );
    } finally {
      semaphore.release();
    }
  }

  Future<MultipartPartResult> _uploadPartWithRetry({
    required _PartSlice part,
    required File file,
    required PartUrlProvider partUrl,
    required MultipartUploadConfig config,
    required CancelToken token,
    required _ProgressAggregator aggregator,
  }) async {
    for (var attempt = 0; attempt < config.maxRetriesPerPart; attempt++) {
      if (attempt > 0) {
        StoneLogger.info(
          '[multipart] retry attempt $attempt for part ${part.partNumber}',
          _tag,
        );
        await Future<void>.delayed(config.retryDelay);
      }
      try {
        if (token.isCancelled) {
          throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          );
        }

        // 每次重试重新取目标：凭证过期可在回调内刷新（legacy L788-800）。
        final target = await partUrl(part.partNumber);

        final response = await _dio.put<dynamic>(
          target.url,
          // 流式读取，内存 O(并发 × 分片)（legacy L834 openRead）。
          data: file.openRead(part.offset, part.end),
          options: Options(
            headers: {
              ...target.headers,
              Headers.contentLengthHeader: '${part.size}',
            },
            sendTimeout: config.sendTimeout,
          ),
          cancelToken: token,
          onSendProgress: (sent, _) => aggregator.update(part.partNumber, sent),
        );

        // dio Headers 大小写不敏感，'ETag'/'etag' 均可命中。
        final eTag = response.headers.value('etag');
        if (eTag == null || eTag.isEmpty) {
          throw Failure(
            code: 'ERR_MISSING_ETAG',
            message: 'Part ${part.partNumber} response carries no ETag',
            type: FailureType.server,
          );
        }

        aggregator.complete(part.partNumber, part.size);
        return MultipartPartResult(
          partNumber: part.partNumber,
          eTag: eTag,
          size: part.size,
        );
      } catch (error) {
        // 取消不重试（legacy L873-876）。
        if (_isCancel(error)) rethrow;
        // 业务判定不可重试（legacy 错误码 3/32，L879-884）。
        if (config.isRetryable?.call(error) == false) rethrow;
        // 最后一次尝试失败即抛出（legacy L887-890）。
        if (attempt == config.maxRetriesPerPart - 1) rethrow;
        StoneLogger.warning(
          '[multipart] part ${part.partNumber} failed '
          '(attempt ${attempt + 1}/${config.maxRetriesPerPart}): $error',
          _tag,
        );
      }
    }
    throw StateError('unreachable: retry loop exhausted');
  }

  StreamController<MultipartProgress> _controllerFor(String taskId) => _progress
      .putIfAbsent(taskId, StreamController<MultipartProgress>.broadcast);

  static bool _isCancel(Object error) =>
      error is DioException && error.type == DioExceptionType.cancel;

  /// DioException → Failure 映射，对齐 `api_client.dart` `_handleError`。
  static Failure _toFailure(Object error) {
    if (error is Failure) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return Failure.timeout(message: 'Connection timeout');
        case DioExceptionType.cancel:
          return const Failure(
            code: 'REQUEST_CANCELLED',
            message: 'Request cancelled',
            type: FailureType.network,
          );
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status == 401) {
            return Failure.unauthorized(message: 'Unauthorized');
          }
          if (status == 403) {
            return const Failure(
              code: 'FORBIDDEN',
              message: 'Forbidden',
              type: FailureType.authentication,
              statusCode: 403,
            );
          }
          return Failure(
            code: 'HTTP_ERROR',
            message: 'Upload part failed (HTTP $status)',
            type: FailureType.server,
            statusCode: status,
          );
        case DioExceptionType.badCertificate:
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return Failure.network(message: 'No internet connection');
          }
          return Failure.server(
            message: 'Upload failed: ${error.message}',
            cause: error,
          );
      }
    }
    return Failure.server(message: 'Upload failed: $error', cause: error);
  }
}
