import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../logger/logger_core.dart';

import 'env_entity.dart';
import 'interceptors/refresh_login_interceptor.dart';
import 'network_abstractions.dart';
import 'refresh_login_model.dart';
import 'response_envelope.dart';

/// HTTP Manager that wraps Dio with interceptors for auth,
/// endpoint routing, host mapping, and error handling.
class HttpManager {
  Dio _dio = Dio();

  static HttpManager? _instance;
  Map<String, EnvEntity> _endpointMap = {};
  Map<String, EnvEntity> get endpointMap => _endpointMap;
  bool _initEndpoint = false;
  final Completer<void> _initCompleter = Completer<void>();

  Map<String, String> _hostMap = {};
  Map<String, String> get hostMap => _hostMap;
  final Completer<void> _initHostCompleter = Completer<void>();
  bool _initHostMap = false;

  int _connectTimeout = 10000;
  int _receiveTimeout = 30000;
  int _sendTimeout = 30000;

  AuthInterceptor? _authInterceptor;
  RefreshLoginInterceptor? _refreshLoginInterceptor;
  AuthConfirm? _authConfirm;
  RefreshLoginModel? _refreshLoginModel;

  /// Singleton access.
  static HttpManager getInstance() {
    _instance ??= HttpManager._();
    return _instance!;
  }

  HttpManager._() {
    _initInterceptors();
    if (!kIsWeb) {
      _dio.httpClientAdapter = _buildAdapter();
    }
    _applyTimeouts();
  }

  void _applyTimeouts() {
    _dio.options.receiveTimeout = Duration(milliseconds: _receiveTimeout);
    _dio.options.connectTimeout = Duration(milliseconds: _connectTimeout);
    _dio.options.sendTimeout = Duration(milliseconds: _sendTimeout);
  }

  /// 构建 HTTP 适配器（onHttpClientCreate 已废弃，迁移到 createHttpClient）。
  IOHttpClientAdapter _buildAdapter({String? proxy}) {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (proxy != null && proxy.isNotEmpty) {
          StoneLogger.info(
            proxy.contains('@')
                ? 'proxy: ${proxy.split('@')[1]}'
                : 'proxy: $proxy',
            'Net',
          );
          client.findProxy = (url) {
            return HttpClient.findProxyFromEnvironment(
              url,
              environment: {
                'http_proxy': proxy,
                'https_proxy': proxy,
                'HTTP_PROXY': proxy,
                'HTTPS_PROXY': proxy,
              },
            );
          };
        }
        client.badCertificateCallback = _badCertificateCallback;
        return client;
      },
    );
  }

  void _initInterceptors() {
    _dio.interceptors.add(EndPointInterceptor());
    _dio.interceptors.add(HostInterceptor());
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        logPrint: (msg) {
          StoneLogger.debug(msg.toString(), 'Net');
        },
      ),
    );
    _dio.interceptors.add(ErrorInterceptor());
    // 有状态拦截器复用实例：enableProxy/disableProxy 重建 Dio 时保留
    // RefreshLoginInterceptor 的单飞刷新状态与已注入的模型/回调
    //（早期实现每次 new，代理切换会丢失刷新中的 Completer）。
    _authInterceptor ??= AuthInterceptor(authConfirm: _authConfirm);
    _dio.interceptors.add(_authInterceptor!);
    _refreshLoginInterceptor ??= RefreshLoginInterceptor(
      refreshLoginModel: _refreshLoginModel,
    );
    _dio.interceptors.add(_refreshLoginInterceptor!);
  }

  void setAuthInterceptor(AuthConfirm? authConfirm) {
    _authConfirm = authConfirm;
    _authInterceptor?.setAuthConfirmCallback(_authConfirm);
  }

  void setRefreshLoginInterceptor(RefreshLoginModel? refreshLoginModel) {
    _refreshLoginModel = refreshLoginModel;
    _refreshLoginInterceptor?.setRefreshLoginModel(_refreshLoginModel);
  }

  bool _badCertificateCallback(X509Certificate cert, String host, int port) {
    if (_hostMap.isNotEmpty) {
      return _hostMap.values.contains(host);
    }
    return true;
  }

  void enableProxy(String proxy) {
    _rebuildDio(proxy: proxy);
  }

  void disableProxy() {
    _rebuildDio();
  }

  /// 重建 Dio（代理开关必须随 adapter 重建；拦截器实例经
  /// [_initInterceptors] 复用，刷新登录的单飞状态不丢失）。
  void _rebuildDio({String? proxy}) {
    _dio.close(force: true);
    _dio = Dio();
    _applyTimeouts();
    _initInterceptors();
    if (!kIsWeb) {
      _dio.httpClientAdapter = _buildAdapter(proxy: proxy);
    }
  }

  void setTimeout({
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
  }) {
    _receiveTimeout = receiveTimeout ?? _receiveTimeout;
    _connectTimeout = connectTimeout ?? _connectTimeout;
    _sendTimeout = sendTimeout ?? _sendTimeout;
    _dio.options.receiveTimeout = Duration(milliseconds: _receiveTimeout);
    _dio.options.connectTimeout = Duration(milliseconds: _connectTimeout);
    _dio.options.sendTimeout = Duration(milliseconds: _sendTimeout);
  }

  Future<void> initEndpointMap() async {
    if (!_initEndpoint) {
      _initEndpoint = true;
      final config = NetworkServiceLocator.config;
      if (config != null) {
        final value = await config.getConfig('endpointMap');
        if (value != null && value.isNotEmpty) {
          try {
            final result = json.decode(value);
            if (result is Map) {
              _endpointMap = result.map((key, value) {
                return MapEntry(
                  key.toString(),
                  EnvEntity.fromJson(value as Map<String, dynamic>),
                );
              });
            }
          } catch (e) {
            StoneLogger.error('init Endpoint error : $e', 'Net');
          }
        }
      }
      _initCompleter.complete();
    } else {
      await _initCompleter.future;
    }
  }

  void setEndpointMap(Map<String, EnvEntity> endpointMap) {
    _endpointMap = endpointMap;
  }

  Future<void> initHostMap() async {
    if (!_initHostMap) {
      _initHostMap = true;
      Map<String, String> hostMap = {};
      final config = NetworkServiceLocator.config;
      if (config != null) {
        try {
          final value = await config.getSecure('wuying.apsarastack.hosts');
          final result = json.decode(value);
          if (result is List) {
            hostMap = result.asMap().map<String, String>(
              (index, value) => MapEntry(
                (value as Map)['wyHostUrl'] as String,
                value['wyHostIp'] as String,
              ),
            );
          }
        } catch (e) {
          // ignore error
        }
      }
      _hostMap = hostMap;
      _initHostCompleter.complete();
    } else {
      await _initHostCompleter.future;
    }
  }

  void setHosts(Map<String, String> hostMap) {
    _hostMap = hostMap;
  }

  Future<Response<T>> request<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
  }) async {
    try {
      return await _request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        retryTimes: retryTimes,
      );
    } on DioException catch (e) {
      final RequestError? requestError = _getRequestError(e, path);
      StoneLogger.error(
        'Http request error(path: $path, error: $requestError)',
        'Net',
      );
      throw requestError!;
    }
  }

  Future<T> requestWithParse<T>(
    String path,
    JsonParse<T> jsonParse, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
    ResponseEnvelope? envelope,
  }) async {
    Response<dynamic>? response;
    try {
      response = await _request(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
        retryTimes: retryTimes,
      );
      // 可选信封：业务码失败按包内异常风格抛 RequestError
      //（SERVER_ERROR + 业务码，使 RefreshLoginInterceptor 的
      // 登出码判定天然可用）；不传 envelope 行为与既往一致。
      if (envelope != null) {
        final body = response.data;
        if (!envelope.isSuccess(body, response.statusCode)) {
          final err = envelope.extractError(body, response.statusCode);
          throw RequestError(
            type: RequestErrorType.SERVER_ERROR,
            code: err.code,
            message: err.message,
            requestId: err.requestId,
            path: path,
          );
        }
        return jsonParse(envelope.extractData(body));
      }
      return jsonParse(response.data);
    } on DioException catch (e) {
      final RequestError? requestError = _getRequestError(e, path);
      StoneLogger.error(
        'Http request error(path: $path, error: $requestError)',
        'Net',
      );
      throw requestError!;
    } catch (e) {
      if (e is RequestError) rethrow;
      StoneLogger.error(
        'Http response parse error(path: $path, error: $e)',
        'Net',
      );
      throw RequestError(
        type: RequestErrorType.PARSE_ERROR,
        requestId: response?.data is Map
            ? (response?.data as Map)['RequestId'] as String?
            : null,
        message: 'Parse error',
        path: path,
      );
    }
  }

  Future<Response<T>> _request<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
  }) async {
    try {
      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
      );
      try {
        if (data is Map) {
          final action = data['Action'];
          StoneLogger.info(
            'Request Action: $action'
                '${action == 'InvokeBffApi' ? ', FunctionName: ${data['FunctionName']}, ServiceName: ${data['ServiceName']}' : ''}',
            'Net',
          );
          if (response.data is Map) {
            // 仅记录轻量元数据：早期实现每次 json.encode 全量响应体，
            // 大响应下有明显 CPU/内存开销且敏感数据入 info 级日志；
            // 完整 body 由默认链上 debug 级 LogInterceptor 兜底。
            final Map<dynamic, dynamic> respData = response.data as Map;
            StoneLogger.info(
              "[api] request: $path, RequestId: ${respData['RequestId']}",
              'Net',
            );
          }
        }
      } catch (e) {
        // ignore logging errors
      }
      return response;
    } on DioException catch (e) {
      if (retryTimes > 0 &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout)) {
        StoneLogger.info(
          '$path request timeout, retry request ($retryTimes)',
          'Net',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (data is Map<String, dynamic>) {
          final body = SplayTreeMap<String, dynamic>.from(data);
          if (body.remove('SignatureNonce') != null) {
            await NetworkServiceLocator.serviceBase?.signature(
              body,
              customSignature: body.containsKey('CustomSignature'),
            );
          }
          data = body;
        }
        return _request(
          path,
          data: data,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          options: options,
          onReceiveProgress: onReceiveProgress,
          onSendProgress: onSendProgress,
          retryTimes: --retryTimes,
        );
      }
      rethrow;
    }
  }

  RequestError? _getRequestError(DioException e, String? path) {
    if (e.error is RequestError) {
      return (e.error as RequestError)..path = path;
    }
    return RequestError.fromDio(e, path: path);
  }

  void setAdapter(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }

  HttpClientAdapter getAdapter() => _dio.httpClientAdapter;
}

// ============================================================
// Built-in Interceptors
// ============================================================

/// Interceptor that applies the endpoint mapping to requests.
class EndPointInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Endpoint routing logic would be applied here.
    // For now, pass through.
    handler.next(options);
  }
}

/// Interceptor that applies host mapping to requests.
///
/// 专有云（Apsara Stack）场景：将请求 host 替换为映射表中的 IP 直连，
/// 原始 host 保留在 `Host` 请求头中（网关/虚拟主机仍可按域名路由）。
///
/// 映射来源（后者优先）：
/// 1. [HttpManager.hostMap] — 安全配置 `wuying.apsarastack.hosts`；
/// 2. `endpointMap['dns'].hosts` — 端点配置内嵌的 DNS 覆盖。
///
/// 替换失败不阻断请求（按原 host 继续）。legacy: pudding HostInterceptor；
/// 行为保真，仅日志改造：不再打印全量映射表（内网 IP 清单不入日志）。
class HostInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final httpManager = HttpManager.getInstance();
      await httpManager.initHostMap();
      final envHosts =
          httpManager.endpointMap['dns']?.hosts ?? const <String, dynamic>{};
      final allHosts = <String, dynamic>{...httpManager.hostMap, ...envHosts};
      final host = options.uri.host;
      final ip = allHosts[host]?.toString();
      if (ip != null && ip.isNotEmpty) {
        StoneLogger.info('HostInterceptor: replacing $host -> $ip', 'Net');
        // 原始 host 进 Host 头（已显式设置时不覆盖）。
        options.headers.putIfAbsent('host', () => host);
        options.path = options.uri.replace(host: ip).toString();
      } else if (allHosts.isNotEmpty) {
        StoneLogger.debug(
          'HostInterceptor: no mapping for $host '
              '(${allHosts.length} entries)',
          'Net',
        );
      }
    } catch (e) {
      StoneLogger.error('HostInterceptor error: $e', 'Net');
    }
    handler.next(options);
  }
}

/// Interceptor that converts Dio errors to [RequestError].
///
/// 把非 [RequestError] 的底层异常统一包装后挂回 [DioException.error]，
/// 使下游（[HttpManager._getRequestError] 与业务层）拿到带类型的错误模型。
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is! RequestError) {
      handler.next(
        err.copyWith(
          error: RequestError.fromDio(err, path: err.requestOptions.path),
        ),
      );
      return;
    }
    handler.next(err);
  }
}

/// Interceptor that adds authentication headers to requests.
class AuthInterceptor extends Interceptor {
  // 规格未到的 pass-through 拦截器：字段经 setter 注入留待鉴权逻辑接入。
  // ignore: unused_field
  AuthConfirm? _authConfirm;

  AuthInterceptor({AuthConfirm? authConfirm}) {
    _authConfirm = authConfirm;
  }

  void setAuthConfirmCallback(AuthConfirm? authConfirm) {
    _authConfirm = authConfirm;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Auth logic would be applied here.
    handler.next(options);
  }
}
