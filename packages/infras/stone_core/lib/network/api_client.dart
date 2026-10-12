/// Stone API Client
///
/// A lightweight, [Result]-based API client wrapping [Dio].
/// All errors are mapped to [Failure] instances for clean
/// Domain-layer integration without fpdart dependency.
///
/// Usage:
/// ```dart
/// final client = ApiClient(dio);
/// final result = await client.get('/users');
/// result.fold(
///   onFailure: (f) => showError(f.message),
///   onSuccess: (data) => parseUsers(data),
/// );
/// ```
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'result.dart';

import 'response_envelope.dart';

/// A clean API client that returns [Result] instead of fpdart Either.
///
/// Wraps [Dio] and converts all HTTP errors into typed [Failure]
/// objects, keeping the Domain layer free of framework concerns.
class ApiClient {
  final Dio _dio;

  /// 构造级默认信封（多后端响应格式兼容；默认直通=无信封层）。
  final ResponseEnvelope _envelope;

  /// Creates an API client backed by the given [Dio] instance.
  ///
  /// [envelope] 设置构造级默认响应信封；每个请求方法可再传入
  /// 单次覆盖（见 [ResponseEnvelope]）。
  ApiClient(this._dio, {ResponseEnvelope? envelope})
    : _envelope = envelope ?? const PassthroughEnvelope();

  /// Performs a GET request.
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
    ResponseEnvelope? envelope,
  }) async {
    try {
      // 必须 <dynamic>：Response<T> 内部的 `as T?` cast 在 T 为模型类时
      // 抛 TypeError（非 DioException），会逃逸本类的 Result 契约。
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Result.failure(_handleError(e));
    }
  }

  /// Performs a POST request.
  Future<Result<T>> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
    ResponseEnvelope? envelope,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Result.failure(_handleError(e));
    }
  }

  /// Performs a PUT request.
  Future<Result<T>> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
    ResponseEnvelope? envelope,
  }) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Result.failure(_handleError(e));
    }
  }

  /// Performs a DELETE request.
  Future<Result<T>> delete<T>(
    String path, {
    T Function(dynamic data)? parser,
    ResponseEnvelope? envelope,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Result.failure(_handleError(e));
    }
  }

  /// Performs a PATCH request.
  Future<Result<T>> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
    ResponseEnvelope? envelope,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(path, data: data);
      return _resolve<T>(response, parser, envelope);
    } on DioException catch (e) {
      return Result.failure(_handleError(e));
    }
  }

  /// Sets the Bearer token in the default Authorization header.
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Removes the Authorization header.
  void removeToken() {
    _dio.options.headers.remove('Authorization');
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// 信封解包 + 数据提取（调用级 [envelope] 覆盖构造级默认）。
  ///
  /// 业务码失败与解析异常均归一为 [Failure]，维持"永不抛"契约。
  Result<T> _resolve<T>(
    Response<dynamic> response,
    T Function(dynamic)? parser,
    ResponseEnvelope? envelope,
  ) {
    final active = envelope ?? _envelope;
    try {
      final body = response.data;
      if (!active.isSuccess(body, response.statusCode)) {
        final err = active.extractError(body, response.statusCode);
        return Result.failure(
          Failure(
            code: err.code ?? 'BIZ_ERROR',
            message: err.message ?? 'Business error',
            type: FailureType.server,
            statusCode: response.statusCode,
            cause: err,
          ),
        );
      }
      final data = active.extractData(body);
      if (parser != null) return Result.success(parser(data));
      return Result.success(data as T);
    } catch (e) {
      return Result.failure(
        Failure.server(message: 'Response handling failed: $e', cause: e),
      );
    }
  }

  /// Maps a [DioException] to a typed [Failure].
  Failure _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Failure.timeout(message: 'Connection timeout');
      case DioExceptionType.badResponse:
        return _mapStatusCode(e.response?.statusCode, e.response?.data);
      case DioExceptionType.cancel:
        return const Failure(
          code: 'REQUEST_CANCELLED',
          message: 'Request cancelled',
          type: FailureType.network,
        );
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return Failure.network(message: 'No internet connection');
        }
        return Failure.server(message: 'Unknown error occurred');
      default:
        return Failure.server(message: 'Unknown error occurred');
    }
  }

  Failure _mapStatusCode(int? statusCode, dynamic data) {
    final msg = data is Map ? (data['message'] as String?) : null;
    switch (statusCode) {
      case 400:
        return Failure.server(
          message: msg ?? 'Bad request',
          code: 'BAD_REQUEST',
        );
      case 401:
        return Failure.unauthorized(
          message: msg ?? 'Unauthorized',
          statusCode: 401,
        );
      case 403:
        return Failure(
          code: 'FORBIDDEN',
          message: msg ?? 'Forbidden',
          type: FailureType.authentication,
          statusCode: 403,
        );
      case 404:
        return Failure.server(message: msg ?? 'Not found', code: 'NOT_FOUND');
      case 500:
      case 501:
      case 502:
      case 503:
        return Failure(
          code: 'SERVER_ERROR',
          message: msg ?? 'Server error',
          type: FailureType.server,
          statusCode: statusCode,
        );
      default:
        return Failure(
          code: 'HTTP_ERROR',
          message: msg ?? 'Unknown error (HTTP $statusCode)',
          type: FailureType.server,
          statusCode: statusCode,
        );
    }
  }
}
