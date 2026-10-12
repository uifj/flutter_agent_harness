/// 领域原语：`Result` / `Failure` / `FailureType`。
///
/// 内联自缺失的 `stone_domain` 包（ADR-0083 D2-②）——原 Wuying "去 stone 化"
/// 抽取时 `stone_domain`/`logger_core`/`network_core` 三个兄弟包被并入
/// `stone_core`，但 import 未改。此处把 `Result`/`Failure` 收回 stone_core 内部，
/// 由 `network_core.dart` 统一 export，调用点改用相对 import。
///
/// 契约与调用点逐一对齐（`api_client` / `multipart_uploader` / `form_post_uploader`
/// 及其测试）：`Result` 双 const 构造 + `.data`(非空) / `.failure`(可空) /
/// `.isSuccess` / `.isFailure` / `.fold`；`Failure.input` 映射到
/// [FailureType.validation]（测试注释称 "input Failure" 但断言 validation）。
library;

/// 失败类别。
enum FailureType {
  /// 服务端错误（5xx、业务码失败、未知错误）。
  server,

  /// 网络层错误（无连接、请求取消）。
  network,

  /// 认证 / 鉴权失败（401 / 403）。
  authentication,

  /// 超时（连接 / 发送 / 接收）。
  timeout,

  /// 数据层错误（分片完整性、解析）。
  data,

  /// 输入校验错误（`Failure.input`：已释放、文件不存在、重复上传）。
  validation,
}

/// 一次失败的结构化描述（永不抛的 API 契约用它替代异常）。
class Failure {
  /// 机器可读的失败码（如 `HTTP_ERROR` / `REQUEST_CANCELLED`）。
  final String code;

  /// 人类可读的失败信息。
  final String message;

  /// 失败类别。
  final FailureType type;

  /// 关联的 HTTP 状态码（若有）。
  final int? statusCode;

  /// 触发失败的底层对象（如 `DioException` / `EnvelopeError`）。
  final Object? cause;

  /// 通用构造（全字段显式）。
  const Failure({
    required this.code,
    required this.message,
    required this.type,
    this.statusCode,
    this.cause,
  });

  /// 服务端错误。
  const Failure.server({
    required this.message,
    this.code = 'SERVER_ERROR',
    this.cause,
  })  : type = FailureType.server,
        statusCode = null;

  /// 网络层错误。
  const Failure.network({
    required this.message,
    this.code = 'NETWORK_ERROR',
  })  : type = FailureType.network,
        statusCode = null,
        cause = null;

  /// 超时错误。
  const Failure.timeout({
    required this.message,
    this.code = 'TIMEOUT',
  })  : type = FailureType.timeout,
        statusCode = null,
        cause = null;

  /// 认证 / 鉴权失败。
  const Failure.unauthorized({
    required this.message,
    this.code = 'UNAUTHORIZED',
    this.statusCode = 401,
  })  : type = FailureType.authentication,
        cause = null;

  /// 输入校验失败（映射到 [FailureType.validation]）。
  const Failure.input({
    required this.message,
    this.code = 'INPUT_ERROR',
  })  : type = FailureType.validation,
        statusCode = null,
        cause = null;

  @override
  String toString() =>
      'Failure(code: $code, message: $message, type: $type, statusCode: $statusCode)';
}

/// 一个"要么成功值、要么 [Failure]"的结果容器（替代 fpdart Either）。
class Result<T> {
  final T? _data;
  final Failure? _failure;

  /// 成功结果。
  const Result.success(T data)
      : _data = data,
        _failure = null;

  /// 失败结果。
  const Result.failure(Failure failure)
      : _data = null,
        _failure = failure;

  /// 是否成功。
  bool get isSuccess => _failure == null;

  /// 是否失败。
  bool get isFailure => _failure != null;

  /// 成功值；失败时访问会抛 [TypeError]（调用方应先判 [isSuccess]）。
  T get data => _data as T;

  /// 失败描述；成功时为 `null`。
  Failure? get failure => _failure;

  /// 二分折叠：成功走 [onSuccess]，失败走 [onFailure]。
  R fold<R>({
    required R Function(Failure failure) onFailure,
    required R Function(T data) onSuccess,
  }) =>
      isFailure ? onFailure(_failure!) : onSuccess(_data as T);

  @override
  String toString() =>
      isFailure ? 'Result.failure($_failure)' : 'Result.success($_data)';
}
