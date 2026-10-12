// RequestErrorType 枚举保持 SCREAMING_CASE：wire/消费者兼容
//（RefreshLoginInterceptor 等按全名匹配，重命名属破坏性变更）。
// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

// ============================================================
// Abstract Interfaces for External Dependencies (sauce/pudding)
// ============================================================

/// Abstract interface for making authenticated API requests.
///
/// Replaces the [ServiceBase] dependency from the pudding package.
abstract class ServiceBaseInterface {
  /// Gets the device UUID.
  Future<String?> getUuid();

  /// Gets the current region ID.
  String get regionId;

  /// Gets the internationality flag.
  bool get internationality;

  /// Sets the internationality flag.
  set internationality(bool value);

  /// Gets the current proxy configuration.
  String? getProxy();

  /// Makes an ECD (Enterprise Cloud Desktop) request.
  Future<T> ecdRequest<T>(
    Map<String, dynamic> param,
    T Function(dynamic jsonStr) jsonParse, {
    String? regionId,
    String? version,
    String? traceId,
    String? spanId,
  });

  /// Makes an AppStream request.
  Future<T> appStreamRequest<T>(
    Map<String, dynamic> param,
    T Function(dynamic jsonStr) jsonParse, {
    String? version,
    String? traceId,
    String? spanId,
    bool supportIntlBeforeLogin = false,
  });

  /// Makes a WYOTA (upgrade) request.
  Future<T> wyotaRequest<T>(
    Map<String, dynamic> param,
    T Function(dynamic jsonStr) jsonParse, {
    String? spanId,
    String? traceId,
  });

  /// Signs a request body with authentication parameters.
  Future<void> signature(
    Map<String, dynamic> body, {
    bool customSignature = false,
  });

  /// Gets the downgrade region ID for a given service type.
  String getDowngradeRegionId(String serviceType);
}

/// Abstract interface for configuration storage.
///
/// Replaces the [Config] dependency from the sauce package.
abstract class ConfigInterface {
  /// Gets a non-secure configuration value.
  Future<String?> getConfig(String key);

  /// Sets a non-secure configuration value.
  Future<void> setConfig(String key, String value);

  /// Gets a secure configuration value.
  Future<String> getSecure(String key);

  /// Sets a secure configuration value.
  Future<void> setSecure(String key, String value);

  /// Gets a system property.
  Future<String?> getProperty(String key);
}

/// Abstract interface for application-level operations.
///
/// Replaces the [Application] dependency from the sauce package.
abstract class ApplicationInterface {
  /// Gets the device name.
  Future<String?> getDeviceName();

  /// Gets the data path for storing application data.
  Future<String?> getDataPath();

  /// Gets the salad bin path.
  Future<String?> getSaladBinPath();
}

/// Abstract interface for global application state (login state).
///
/// Replaces the [GlobalStore] dependency from the pudding package.
abstract class GlobalStoreInterface {
  /// Gets the current login token.
  String get loginToken;

  /// Gets the current session ID.
  String get sessionId;

  /// Whether the current user is a personal account.
  bool get isPersonal;

  /// Saves the login state.
  Future<void> saveStore({
    required String tenantId,
    required String loginToken,
    required String sessionId,
  });
}

/// Abstract interface for distributed function tracing.
///
/// Replaces the [FunctionTracer] dependency from the tracer package.
abstract class FunctionTracerInterface {
  /// Adds a trace event.
  void addTrace(String event, {String? detail, String? error});
}

/// Typedef for authentication confirmation callback.
typedef AuthConfirm = Future<String?> Function();

// ============================================================
// Request Error Model
// ============================================================

/// Types of request errors.
enum RequestErrorType {
  NETWORK_ERROR,
  SERVER_ERROR,
  PARSE_ERROR,
  CANCEL,
  TIMEOUT,
  UNKNOWN,
}

/// Standardized request error model.
///
/// Replaces the [RequestError] dependency from the pudding package.
class RequestError implements Exception {
  final RequestErrorType type;
  final String? code;
  final String? message;
  final String? requestId;
  String? path;

  RequestError({
    this.type = RequestErrorType.UNKNOWN,
    this.code,
    this.message,
    this.requestId,
    this.path,
  });

  /// 由 [DioException] 构造带类型的 [RequestError]。
  ///
  /// 替代早期空实现的 [setTypeMessage]（type 为 final，事后赋类型不可行，
  /// 导致错误类型恒为 UNKNOWN）。
  factory RequestError.fromDio(DioException e, {String? path}) {
    final type = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => RequestErrorType.TIMEOUT,
      DioExceptionType.cancel => RequestErrorType.CANCEL,
      DioExceptionType.badResponse => RequestErrorType.SERVER_ERROR,
      DioExceptionType.badCertificate ||
      DioExceptionType.connectionError => RequestErrorType.NETWORK_ERROR,
      DioExceptionType.unknown =>
        e.error is SocketException
            ? RequestErrorType.NETWORK_ERROR
            : RequestErrorType.UNKNOWN,
    };
    final data = e.response?.data;
    return RequestError(
      type: type,
      code: e.response?.statusCode?.toString(),
      message: e.message,
      requestId: data is Map ? data['RequestId'] as String? : null,
      path: path,
    );
  }

  /// Sets the type and message from a [DioException].
  @Deprecated('type is final and cannot be set here; use RequestError.fromDio')
  void setTypeMessage(DioException e) {
    // Handled by the caller; type is already set via constructor.
  }

  @override
  String toString() =>
      'RequestError(type: $type, code: $code, message: $message, path: $path)';
}

// ============================================================
// Platform Information
// ============================================================

/// Platform utility providing OS information.
///
/// Replaces the [WYPlatform] dependency from the sauce package.
class WYPlatform {
  /// The operating system name (e.g., 'Windows', 'macOS', 'Linux').
  static String get operatingSystem {
    // This is a stub; real implementation would detect the platform.
    return 'Unknown';
  }

  /// The operating system version string.
  static String get operatingSystemVersion {
    return '0.0.0';
  }
}

/// JSON parse typedef.
typedef JsonParse<T> = T Function(dynamic jsonStr);

// ============================================================
// Service Locator (Singleton Access)
// ============================================================

/// Service locator for the network layer abstractions.
///
/// Provides access to the singleton instances of core services.
/// These must be initialized by the application layer before use.
class NetworkServiceLocator {
  // 直接公共字段：早期 getter/setter 纯包裹无附加逻辑
  //（unnecessary_getters_setters），调用方式不变。
  static ServiceBaseInterface? serviceBase;
  static ConfigInterface? config;
  static ApplicationInterface? application;
  static GlobalStoreInterface? globalStore;
  static FunctionTracerInterface? functionTracer;
}
