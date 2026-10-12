import 'dart:io';

import 'package:dio/dio.dart';
import '../../logger/logger_core.dart';

/// Interceptor that retries failed requests
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 5),
    ],
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldRetry(err)) {
      // 重试计数存 extra（内部元数据不随请求发往服务端；
      // 早期实现误写入 headers 导致 retry_attempt 泄漏到 HTTP 请求头）。
      final attempt = (err.requestOptions.extra['retry_attempt'] ?? 0) as int;

      if (attempt < maxRetries && attempt < retryDelays.length) {
        final delay = retryDelays[attempt];
        StoneLogger.info(
          'Retry attempt ${attempt + 1}/$maxRetries for '
              '${err.requestOptions.path} after ${delay.inSeconds}s',
          'Net',
        );

        // Update retry attempt count
        err.requestOptions.extra['retry_attempt'] = attempt + 1;

        // Wait before retrying
        await Future<void>.delayed(delay);

        try {
          // Clone the request and retry
          final options = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            contentType: err.requestOptions.contentType,
            responseType: err.requestOptions.responseType,
            followRedirects: err.requestOptions.followRedirects,
            listFormat: err.requestOptions.listFormat,
            receiveTimeout: err.requestOptions.receiveTimeout,
            sendTimeout: err.requestOptions.sendTimeout,
            validateStatus: err.requestOptions.validateStatus,
            extra: err.requestOptions.extra,
          );

          final response = await dio.request<dynamic>(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            cancelToken: err.requestOptions.cancelToken,
            options: options,
            onSendProgress: err.requestOptions.onSendProgress,
            onReceiveProgress: err.requestOptions.onReceiveProgress,
          );

          return handler.resolve(response);
        } catch (e) {
          // 透传最后一次重试的错误（回传首个错误会让上层拿到过期信息，
          // 如首次超时/末次 500 只见超时）。
          if (e is DioException) {
            return super.onError(e, handler);
          }
          return super.onError(err, handler);
        }
      }
    }

    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.type == DioExceptionType.unknown &&
            err.error != null &&
            err.error is SocketException);
  }
}
