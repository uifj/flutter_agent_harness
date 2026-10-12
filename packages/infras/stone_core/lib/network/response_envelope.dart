/// 响应信封（Response Envelope）— 多后端返回格式兼容层。
///
/// 不同后端的响应包装方式不同：
/// - wyota/FaaS：Pascal 键 `{RequestId, ResultCode, ResultMessage, ...}`；
/// - 通用 REST：`{code, message, data}`；
/// - Supabase/OSS 等：裸 body 或无 body。
///
/// 信封策略定义"如何从原始 body 判定业务成败并提取数据段"，
/// 支持两级注入：[ApiClient] 构造级默认 + 单次调用传入覆盖。
/// 默认 [PassthroughEnvelope] 直通，不注入时行为与无信封层完全一致。
///
/// 设计参考：《Flutter Dio高阶封装&多级缓存策略》的统一响应结构
/// `ApiResult{code,message,data}`，泛化为可配置策略以覆盖多后端。
library;

/// 信封解析出的业务错误信息（挂到 Failure.cause / RequestError 保留上下文）。
class EnvelopeError {
  const EnvelopeError({this.code, this.message, this.requestId});

  /// 业务错误码（如 'not_login'、'InvalidParameter'）。
  final String? code;

  final String? message;

  /// 服务端请求追踪 id（wyota RequestId 等）。
  final String? requestId;

  @override
  String toString() =>
      'EnvelopeError(code: $code, message: $message, requestId: $requestId)';
}

/// 响应信封策略。
abstract class ResponseEnvelope {
  const ResponseEnvelope();

  /// 业务是否成功（[statusCode] 供需要 HTTP 语义参与判定的实现使用）。
  bool isSuccess(dynamic body, int? statusCode);

  /// 提取业务数据段（成功时交给上层 parser/jsonParse）。
  dynamic extractData(dynamic body);

  /// 提取业务错误（[isSuccess] 为 false 时调用）。
  EnvelopeError extractError(dynamic body, int? statusCode);
}

/// 直通信封：永远成功、数据段即原始 body（默认值，等价于无信封层）。
class PassthroughEnvelope extends ResponseEnvelope {
  const PassthroughEnvelope();

  @override
  bool isSuccess(dynamic body, int? statusCode) => true;

  @override
  dynamic extractData(dynamic body) => body;

  @override
  EnvelopeError extractError(dynamic body, int? statusCode) =>
      const EnvelopeError();
}

/// 通用 REST 信封：`{code, message, data}`（键名与成功码集可配置）。
///
/// 保守回退：body 非 Map 或缺 [codeKey] 时视为成功直通（防止误伤
/// 未包装的接口）。
class RestCodeEnvelope extends ResponseEnvelope {
  const RestCodeEnvelope({
    this.codeKey = 'code',
    this.messageKey = 'message',
    this.dataKey = 'data',
    this.requestIdKey = 'requestId',
    this.successCodes = const {0, 200},
  });

  final String codeKey;
  final String messageKey;
  final String dataKey;
  final String requestIdKey;

  /// 视为成功的业务码集合（int 或其字符串形式均可匹配）。
  final Set<int> successCodes;

  bool _hasEnvelope(dynamic body) => body is Map && body.containsKey(codeKey);

  int? _codeOf(dynamic body) {
    final raw = (body as Map)[codeKey];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  @override
  bool isSuccess(dynamic body, int? statusCode) {
    if (!_hasEnvelope(body)) return true;
    final code = _codeOf(body);
    return code != null && successCodes.contains(code);
  }

  @override
  dynamic extractData(dynamic body) =>
      _hasEnvelope(body) ? (body as Map)[dataKey] : body;

  @override
  EnvelopeError extractError(dynamic body, int? statusCode) {
    if (body is! Map) return const EnvelopeError();
    return EnvelopeError(
      code: '${body[codeKey]}',
      message: body[messageKey]?.toString(),
      requestId: body[requestIdKey]?.toString(),
    );
  }
}

/// wyota/FaaS 信封：Pascal 键 `ResultCode`/`ResultMessage`/`RequestId`
///（本仓 FaaS 域实测格式，参见 upgrade/feedback 的 wire 模型）。
///
/// `ResultCode` 为 null/''/'0'/'Success'（另兼容小写 'success'，
/// 多后端大小写不一致的容错项）视为成功；数据段即原 body
///（wyota 业务字段与信封字段平铺，不做剥离）。
class WyotaEnvelope extends ResponseEnvelope {
  const WyotaEnvelope();

  static const Set<String> _successCodes = {'', '0', 'Success', 'success'};

  @override
  bool isSuccess(dynamic body, int? statusCode) {
    if (body is! Map) return true;
    final raw = body['ResultCode'];
    if (raw == null) return true;
    return _successCodes.contains('$raw');
  }

  @override
  dynamic extractData(dynamic body) => body;

  @override
  EnvelopeError extractError(dynamic body, int? statusCode) {
    if (body is! Map) return const EnvelopeError();
    return EnvelopeError(
      code: body['ResultCode']?.toString(),
      message: body['ResultMessage']?.toString(),
      requestId: body['RequestId']?.toString(),
    );
  }
}
