import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'env_entity.dart';
import 'http_manager.dart';
import 'network_abstractions.dart';
import 'refresh_login_model.dart';
import 'response_envelope.dart';

const buildVersionKey = 'ro.sd.build.version';
const clientIdKey = 'wuying.client.id';

/// Static HTTP utility methods providing convenient wrappers
/// around [HttpManager] for common request patterns.
abstract class HttpUtils {
  static String? _clientId;
  static String? _clientVersion;

  static Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
  }) {
    return HttpManager.getInstance().request(
      path,
      options: _checkOptions('GET', options),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      retryTimes: retryTimes,
    );
  }

  static Future<Response<dynamic>> post(
    String path, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
  }) {
    return HttpManager.getInstance().request(
      path,
      data: data,
      options: _checkOptions('POST', options),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      retryTimes: retryTimes,
    );
  }

  static Future<Response<T>> request<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
  }) {
    return HttpManager.getInstance().request(
      path,
      data: data,
      options: options,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      retryTimes: retryTimes,
    );
  }

  static Future<T> getWithParse<T>(
    String path,
    JsonParse<T> jsonParse, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
    ResponseEnvelope? envelope,
  }) {
    return HttpManager.getInstance().requestWithParse(
      path,
      jsonParse,
      options: _checkOptions('GET', options),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      retryTimes: retryTimes,
      envelope: envelope,
    );
  }

  static Future<T> postWithParse<T>(
    String path,
    JsonParse<T> jsonParse, {
    required dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    int retryTimes = 0,
    ResponseEnvelope? envelope,
  }) {
    return HttpManager.getInstance().requestWithParse(
      path,
      jsonParse,
      data: data,
      options: _checkOptions('POST', options),
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
      retryTimes: retryTimes,
      envelope: envelope,
    );
  }

  static void setEndpointMap(Map<String, EnvEntity> map) {
    HttpManager.getInstance().setEndpointMap(map);
  }

  static void setHostMap(Map<String, String> map) {
    HttpManager.getInstance().setHosts(map);
  }

  static void enableProxy(String proxy) {
    HttpManager.getInstance().enableProxy(proxy);
  }

  static void disableProxy() {
    HttpManager.getInstance().disableProxy();
  }

  static void setTimeout({
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
  }) {
    HttpManager.getInstance().setTimeout(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
    );
  }

  static void setAuthConfirmCallback(AuthConfirm? authConfirm) {
    HttpManager.getInstance().setAuthInterceptor(authConfirm);
  }

  /// Sets the login token refresh model.
  static void setRefreshLoginToken(RefreshLoginModel? refreshLoginModel) {
    HttpManager.getInstance().setRefreshLoginInterceptor(refreshLoginModel);
  }

  static Options _checkOptions(String method, Options? options) {
    options ??= Options();
    options.method = method;
    return options;
  }

  static Future<String> _getClientId() async {
    final config = NetworkServiceLocator.config;
    if (config != null) {
      final id = await config.getConfig(clientIdKey);
      if (id != null && id.isNotEmpty) {
        _clientId = id;
        return id;
      }
    }
    final clientId = const Uuid().v4();
    _clientId = clientId;
    await NetworkServiceLocator.config?.setConfig(clientIdKey, clientId);
    return clientId;
  }

  static Future<String?> _getClientVersion() async {
    final version = await NetworkServiceLocator.config?.getProperty(
      buildVersionKey,
    );
    _clientVersion = version;
    return version;
  }

  /// Builds the base parameter map for API requests.
  static Future<SplayTreeMap<String, dynamic>> getBaseParamMap({
    String product = 'ecs_ad',
    String version = '2020-10-02',
    String? uuid,
    String? loginToken,
    String? sessionId,
    bool vpc = false,
  }) async {
    final clientOS =
        '${WYPlatform.operatingSystem}_${WYPlatform.operatingSystemVersion}';
    final map = SplayTreeMap<String, dynamic>();
    final clientId = _clientId ?? await _getClientId();
    final clientVersion = _clientVersion ?? await _getClientVersion();
    map['ClientOS'] = clientOS;
    map['ClientType'] = WYPlatform.operatingSystem;
    map['ClientId'] = clientId;
    map['ClientVersion'] = clientVersion;
    map['Format'] = 'json';
    map['Product'] = product;
    map['Version'] = version;
    if (uuid != null) {
      map['Uuid'] = uuid;
    }
    if (loginToken != null) {
      map['LoginToken'] = loginToken;
    }
    if (sessionId != null) {
      map['SessionId'] = sessionId;
    }
    return map;
  }
}
