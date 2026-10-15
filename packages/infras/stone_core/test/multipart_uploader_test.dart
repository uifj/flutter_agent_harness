/// MultipartUploader 单元测试 —— mocktail mock Dio，零真实网络。
///
/// 覆盖行为保真清单：分片切割边界、并发上限、断点续传、重试策略
/// （取消/不可重试/耗尽）、快速失败、完整性校验、进度节流与终值、
/// per-task 取消与错误映射。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stone_core/network_core.dart';

class _MockDio extends Mock implements Dio {}

/// 快速配置：重试间隔归零，缩短用例耗时。
MultipartUploadConfig _config({
  int partSize = 4,
  int maxConcurrent = 5,
  int maxRetriesPerPart = 5,
  Duration progressInterval = const Duration(milliseconds: 500),
  bool Function(Object)? isRetryable,
}) {
  return MultipartUploadConfig(
    partSize: partSize,
    maxConcurrent: maxConcurrent,
    maxRetriesPerPart: maxRetriesPerPart,
    retryDelay: Duration.zero,
    progressInterval: progressInterval,
    isRetryable: isRetryable,
  );
}

Response<dynamic> _okResponse({String eTag = 'etag'}) => Response(
  requestOptions: RequestOptions(),
  statusCode: 200,
  headers: Headers.fromMap({
    'ETag': [eTag],
  }),
);

void main() {
  late Directory tempDir;
  late _MockDio dio;
  late MultipartUploader uploader;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('multipart_test');
    dio = _MockDio();
    uploader = MultipartUploader(dio: dio);
  });

  tearDown(() {
    uploader.dispose();
    tempDir.deleteSync(recursive: true);
  });

  File writeFile(String name, int bytes) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List.generate(bytes, (i) => i % 251));
    return file;
  }

  /// 记录每次 PUT 的 URL，并按需定制响应。
  List<String> stubPut({
    Future<Response<dynamic>> Function(Invocation invocation)? onCall,
  }) {
    final urls = <String>[];
    when(
      () => dio.put<dynamic>(
        any(),
        data: any<dynamic>(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
        onSendProgress: any(named: 'onSendProgress'),
      ),
    ).thenAnswer((invocation) {
      urls.add(invocation.positionalArguments.first as String);
      if (onCall != null) return onCall(invocation);
      return Future.value(_okResponse());
    });
    return urls;
  }

  Future<MultipartTarget> partUrl(int partNumber) async =>
      MultipartTarget(url: 'https://oss.example/part/$partNumber');

  group('分片切割', () {
    test('余数尾片：10 字节 / 4B 分片 → 3 片，尾片 2 字节', () async {
      final file = writeFile('a.bin', 10);
      final urls = stubPut();

      final result = await uploader.uploadFile(
        taskId: 't1',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(result.isSuccess, isTrue);
      final parts = result.data.parts;
      expect(parts.map((p) => p.partNumber), [1, 2, 3]);
      expect(parts.map((p) => p.size), [4, 4, 2]);
      expect(result.data.totalBytes, 10);
      expect(urls, hasLength(3));
    });

    test('整除：8 字节 / 4B → 2 片', () async {
      final file = writeFile('b.bin', 8);
      stubPut();

      final result = await uploader.uploadFile(
        taskId: 't2',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(result.data.parts.map((p) => p.size), [4, 4]);
    });

    test('文件小于一片 → 1 片', () async {
      final file = writeFile('c.bin', 3);
      stubPut();

      final result = await uploader.uploadFile(
        taskId: 't3',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(result.data.parts.single.size, 3);
    });

    test('空文件 → 0 片成功，进度终值 1.0', () async {
      final file = writeFile('d.bin', 0);
      stubPut();

      final events = <MultipartProgress>[];
      final sub = uploader.watchProgress('t4').listen(events.add);

      final result = await uploader.uploadFile(
        taskId: 't4',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.isSuccess, isTrue);
      expect(result.data.parts, isEmpty);
      expect(events.last.progress, 1.0);
      verifyNever(
        () => dio.put<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    test('文件不存在 → validation Failure', () async {
      final result = await uploader.uploadFile(
        taskId: 't5',
        filePath: '${tempDir.path}/missing.bin',
        partUrl: partUrl,
      );

      expect(result.isFailure, isTrue);
      expect(result.failure!.type, FailureType.validation);
    });
  });

  group('并发控制', () {
    test('在途请求峰值 ≤ maxConcurrent', () async {
      final file = writeFile('e.bin', 40); // 10 片
      var inFlight = 0;
      var peak = 0;
      stubPut(
        onCall: (_) async {
          inFlight++;
          peak = peak > inFlight ? peak : inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
          return _okResponse();
        },
      );

      final result = await uploader.uploadFile(
        taskId: 't6',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(maxConcurrent: 3),
      );

      expect(result.isSuccess, isTrue);
      expect(peak, lessThanOrEqualTo(3));
      expect(peak, greaterThan(1), reason: '应确实并发而非串行');
    });
  });

  group('断点续传', () {
    test('跳过已传分片，eTag 合并且结果有序', () async {
      final file = writeFile('f.bin', 10); // 3 片
      final urls = stubPut();

      final result = await uploader.uploadFile(
        taskId: 't7',
        filePath: file.path,
        partUrl: partUrl,
        uploadedParts: const {1: 'resumed-etag'},
        config: _config(),
      );

      expect(result.isSuccess, isTrue);
      expect(urls, hasLength(2), reason: '只应上传缺失的 2、3 片');
      expect(urls.any((u) => u.endsWith('/1')), isFalse);
      final parts = result.data.parts;
      expect(parts.map((p) => p.partNumber), [1, 2, 3]);
      expect(parts.first.eTag, 'resumed-etag');
      expect(parts.first.size, 4);
    });

    test('越界的历史分片号被忽略', () async {
      final file = writeFile('g.bin', 4); // 1 片
      stubPut();

      final result = await uploader.uploadFile(
        taskId: 't8',
        filePath: file.path,
        partUrl: partUrl,
        uploadedParts: const {9: 'stale'},
        config: _config(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data.parts.single.partNumber, 1);
    });
  });

  group('重试策略', () {
    test('前 2 次网络错误，第 3 次成功', () async {
      final file = writeFile('h.bin', 4);
      var attempts = 0;
      stubPut(
        onCall: (_) {
          attempts++;
          if (attempts < 3) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.unknown,
              error: const SocketException('reset'),
            );
          }
          return Future.value(_okResponse());
        },
      );

      final result = await uploader.uploadFile(
        taskId: 't9',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(result.isSuccess, isTrue);
      expect(attempts, 3);
    });

    test('取消错误不重试，映射为 REQUEST_CANCELLED', () async {
      final file = writeFile('i.bin', 4);
      var attempts = 0;
      stubPut(
        onCall: (_) {
          attempts++;
          throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          );
        },
      );

      final result = await uploader.uploadFile(
        taskId: 't10',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure!.code, 'REQUEST_CANCELLED');
      expect(attempts, 1);
    });

    test('isRetryable 返回 false 时零重试', () async {
      final file = writeFile('j.bin', 4);
      var attempts = 0;
      stubPut(
        onCall: (_) {
          attempts++;
          throw StateError('file locked');
        },
      );

      final result = await uploader.uploadFile(
        taskId: 't11',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(isRetryable: (_) => false),
      );

      expect(result.isFailure, isTrue);
      expect(attempts, 1);
    });

    test('每次重试重新调用 partUrl（凭证可刷新）', () async {
      final file = writeFile('k.bin', 4);
      var urlCalls = 0;
      var attempts = 0;
      stubPut(
        onCall: (_) {
          attempts++;
          if (attempts < 2) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: RequestOptions(),
                statusCode: 403,
              ),
            );
          }
          return Future.value(_okResponse());
        },
      );

      final result = await uploader.uploadFile(
        taskId: 't12',
        filePath: file.path,
        partUrl: (n) async {
          urlCalls++;
          return MultipartTarget(url: 'https://oss.example/$n');
        },
        config: _config(),
      );

      expect(result.isSuccess, isTrue);
      expect(urlCalls, 2, reason: '重试须重新取目标以支持凭证刷新');
    });
  });

  group('快速失败与完整性', () {
    test('一片耗尽重试 → 整体 Failure 且外部 token 被取消', () async {
      final file = writeFile('l.bin', 12); // 3 片
      stubPut(
        onCall: (invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/2')) {
            throw DioException(
              requestOptions: RequestOptions(),
              type: DioExceptionType.connectionError,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _okResponse();
        },
      );

      final token = CancelToken();
      final result = await uploader.uploadFile(
        taskId: 't13',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(maxRetriesPerPart: 2),
        cancelToken: token,
      );

      expect(result.isFailure, isTrue);
      expect(token.isCancelled, isTrue, reason: '兄弟分片失败后应取消在途请求');
    });

    test('响应缺失 ETag → ERR_MISSING_ETAG Failure', () async {
      final file = writeFile('m.bin', 4);
      stubPut(
        onCall: (_) => Future.value(
          Response<dynamic>(requestOptions: RequestOptions(), statusCode: 200),
        ),
      );

      final result = await uploader.uploadFile(
        taskId: 't14',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(maxRetriesPerPart: 2),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure!.code, 'ERR_MISSING_ETAG');
    });
  });

  group('进度', () {
    test('节流生效且终值 1.0 必达', () async {
      final file = writeFile('n.bin', 40); // 10 片
      var callbacks = 0;
      stubPut(
        onCall: (invocation) async {
          final onSend =
              invocation.namedArguments[const Symbol('onSendProgress')]
                  as ProgressCallback?;
          // 模拟高频进度回调。
          for (var i = 1; i <= 4; i++) {
            onSend?.call(i, 4);
            callbacks++;
          }
          return _okResponse();
        },
      );

      final events = <MultipartProgress>[];
      final sub = uploader.watchProgress('t15').listen(events.add);

      final result = await uploader.uploadFile(
        taskId: 't15',
        filePath: file.path,
        partUrl: partUrl,
        // 大节流窗口：中间事件应被吞掉，只留完成附近的强制发射。
        config: _config(progressInterval: const Duration(seconds: 10)),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.isSuccess, isTrue);
      expect(callbacks, 40);
      expect(events.length, lessThan(callbacks), reason: '节流应显著压缩事件数');
      expect(events.last.progress, 1.0);
      expect(events.last.bytesSent, 40);
    });

    test('watchProgress 为 broadcast，多订阅者互不影响', () async {
      final stream = uploader.watchProgress('t16');
      expect(stream.isBroadcast, isTrue);
      final sub1 = stream.listen((_) {});
      final sub2 = stream.listen((_) {});
      await sub1.cancel();
      await sub2.cancel();
    });
  });

  group('取消与错误映射', () {
    test('cancel(taskId) → REQUEST_CANCELLED', () async {
      final file = writeFile('o.bin', 8);
      stubPut(
        onCall: (invocation) async {
          final token =
              invocation.namedArguments[const Symbol('cancelToken')]
                  as CancelToken?;
          // 挂起直到被取消（模拟慢速在途请求）。
          await token!.whenCancel;
          throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          );
        },
      );

      final pending = uploader.uploadFile(
        taskId: 't17',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      uploader.cancel('t17');

      final result = await pending;
      expect(result.isFailure, isTrue);
      expect(result.failure!.code, 'REQUEST_CANCELLED');
    });

    test('超时 → timeout Failure；401 → authentication Failure', () async {
      final file = writeFile('p.bin', 4);

      stubPut(
        onCall: (_) => throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.sendTimeout,
        ),
      );
      var result = await uploader.uploadFile(
        taskId: 't18',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(maxRetriesPerPart: 2),
      );
      // 与 api_client._handleError 一致：四种 timeout 都归 FailureType.timeout。
      expect(result.failure!.type, FailureType.timeout);

      stubPut(
        onCall: (_) => throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(), statusCode: 401),
        ),
      );
      result = await uploader.uploadFile(
        taskId: 't19',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(maxRetriesPerPart: 2),
      );
      expect(result.failure!.type, FailureType.authentication);
    });
  });

  group('生命周期与审计回归', () {
    test(
      'dispose 后 uploadFile 返回 Failure，watchProgress 抛 StateError',
      () async {
        final file = writeFile('q.bin', 4);
        stubPut();
        uploader.dispose();

        final result = await uploader.uploadFile(
          taskId: 't20',
          filePath: file.path,
          partUrl: partUrl,
          config: _config(),
        );
        expect(result.isFailure, isTrue);
        expect(result.failure!.type, FailureType.validation);
        expect(() => uploader.watchProgress('t20'), throwsStateError);
      },
    );

    test('同 taskId 并发上传被拒绝', () async {
      final file = writeFile('r.bin', 8);
      stubPut(
        onCall: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _okResponse();
        },
      );

      final first = uploader.uploadFile(
        taskId: 't21',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = await uploader.uploadFile(
        taskId: 't21',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );

      expect(second.isFailure, isTrue);
      expect(second.failure!.message, contains('already in progress'));
      expect((await first).isSuccess, isTrue, reason: '在途任务不受影响');
    });

    test('任务结束后进度流关闭（防长驻泄漏），重传可重新订阅', () async {
      final file = writeFile('s.bin', 4);
      stubPut();

      var done = false;
      final sub = uploader
          .watchProgress('t22')
          .listen((_) {}, onDone: () => done = true);

      final result = await uploader.uploadFile(
        taskId: 't22',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.isSuccess, isTrue);
      expect(done, isTrue, reason: '任务结束后对应进度流应关闭并从内部 map 移除');

      // 同 taskId 可再次上传（控制器已回收，重新订阅拿到新流）。
      final again = await uploader.uploadFile(
        taskId: 't22',
        filePath: file.path,
        partUrl: partUrl,
        config: _config(),
      );
      expect(again.isSuccess, isTrue);
    });

    test('断点续传的初始已传字节计入进度', () async {
      final file = writeFile('u.bin', 12); // 3 片，第 1 片已传
      stubPut(
        onCall: (invocation) async {
          final onSend =
              invocation.namedArguments[const Symbol('onSendProgress')]
                  as ProgressCallback?;
          onSend?.call(4, 4);
          return _okResponse();
        },
      );

      final events = <MultipartProgress>[];
      final sub = uploader.watchProgress('t23').listen(events.add);

      final result = await uploader.uploadFile(
        taskId: 't23',
        filePath: file.path,
        partUrl: partUrl,
        uploadedParts: const {1: 'resumed'},
        config: _config(),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.isSuccess, isTrue);
      expect(events, isNotEmpty);
      expect(
        events.first.bytesSent,
        greaterThanOrEqualTo(4),
        reason: '进度应从已传分片的字节量起步，而非 0',
      );
      expect(events.last.progress, 1.0);
    });
  });
}
