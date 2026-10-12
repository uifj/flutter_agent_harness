/// 分片上传引擎 — 数据模型与配置。
///
/// 行为规格来源（legacy）：`appunits/file_transfer/lib_old/src/service/oss_client.dart`。
/// 默认参数逐项对齐 legacy 实现（分片 20MB / 并发 5 / 重试 5×1s / 节流 500ms），
/// 保证行为保真；均可经 [MultipartUploadConfig] 覆盖。
///
/// 分层约束（白皮书 L2 基石层）：本模块与业务协议无关 —— 分片会话
/// （initiate / 取凭证 / complete）与凭证获取（WyDrive FaaS、OSS V1 签名等）
/// 留在业务层，引擎仅消费 [PartUrlProvider] 注入的预签名上传目标。
library;

/// 为指定分片提供上传目标（预签名 URL + 请求头）。
///
/// 由调用方注入；每次重试都会重新调用，因此凭证过期刷新可在回调内实现
/// （legacy: oss_client.dart L788-800 的 403 刷新 ossConfig 场景由此天然覆盖）。
typedef PartUrlProvider = Future<MultipartTarget> Function(int partNumber);

/// 单个分片的上传目标。
class MultipartTarget {
  /// Creates an upload target for one part.
  const MultipartTarget({required this.url, this.headers = const {}});

  /// 预签名 PUT URL。
  final String url;

  /// 额外请求头（如 OSS 签名 / STS token 头）。
  final Map<String, String> headers;
}

/// 分片上传配置；默认值 = legacy `oss_client.dart` 规格。
class MultipartUploadConfig {
  /// Creates a config; every default mirrors the legacy behaviour.
  const MultipartUploadConfig({
    this.partSize = 20 * 1024 * 1024,
    this.maxConcurrent = 5,
    this.maxRetriesPerPart = 5,
    this.retryDelay = const Duration(seconds: 1),
    this.progressInterval = const Duration(milliseconds: 500),
    this.sendTimeout = const Duration(seconds: 120),
    this.isRetryable,
  }) : assert(partSize > 0, 'partSize must be positive'),
       assert(maxConcurrent > 0, 'maxConcurrent must be positive'),
       assert(maxRetriesPerPart > 0, 'maxRetriesPerPart must be positive');

  /// 分片大小（字节）。legacy: L341/L514（20MB 固定）。
  final int partSize;

  /// 最大并发分片数；内存占用上限 O(maxConcurrent × partSize)。legacy: L516。
  final int maxConcurrent;

  /// 每分片最大尝试次数（含首次）。legacy: L726。
  final int maxRetriesPerPart;

  /// 重试间隔（固定，不做指数退避 —— 对齐 legacy L727）。
  final Duration retryDelay;

  /// 进度节流间隔；进度完成（>=1.0）时强制发射。legacy: L145-147。
  final Duration progressInterval;

  /// 单分片 PUT 发送超时（大分片需要比全局 30s 更长的窗口）。
  final Duration sendTimeout;

  /// 判定错误是否可重试；返回 false 则立即失败。
  ///
  /// null 时全部按可重试处理（取消错误除外，取消永不重试）。
  /// legacy: L879-884 的原生错误码 3/32（路径超长/文件被占用）不可重试 ——
  /// 该判断属调用方协议知识，故泛化为回调注入。
  final bool Function(Object error)? isRetryable;
}

/// 分片上传进度快照（节流后发射）。
class MultipartProgress {
  /// Creates a progress snapshot.
  const MultipartProgress({
    required this.taskId,
    required this.bytesSent,
    required this.totalBytes,
    required this.progress,
    required this.bytesPerSecond,
  });

  /// 所属任务。
  final String taskId;

  /// 已发送字节（含断点续传的初始已传字节）。
  final int bytesSent;

  /// 文件总字节。
  final int totalBytes;

  /// 总进度，已 clamp 到 [0, 1]。
  final double progress;

  /// 瞬时速度（字节/秒），NaN/Inf/负值已防御为 0。
  final int bytesPerSecond;

  @override
  String toString() =>
      'MultipartProgress($taskId ${(progress * 100).toStringAsFixed(1)}% '
      '$bytesSent/$totalBytes ${bytesPerSecond}B/s)';
}

/// 单分片上传结果。
class MultipartPartResult {
  /// Creates a part result.
  const MultipartPartResult({
    required this.partNumber,
    required this.eTag,
    required this.size,
  });

  /// 分片号（从 1 开始）。
  final int partNumber;

  /// 服务端返回的 ETag（complete 提交时使用）。
  final String eTag;

  /// 分片字节数。
  final int size;
}

/// 整体上传结果：全部分片（含断点续传注入的历史分片）按 partNumber 升序。
class MultipartUploadResult {
  /// Creates an upload result.
  const MultipartUploadResult({required this.parts, required this.totalBytes});

  /// 已排序、去重、完整性校验通过的分片结果列表。
  final List<MultipartPartResult> parts;

  /// 文件总字节。
  final int totalBytes;
}
