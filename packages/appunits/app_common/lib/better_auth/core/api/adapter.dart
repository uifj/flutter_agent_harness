import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:stone_core/logger/logger_core.dart';

import 'models/result/better_error.dart';
import 'models/result/result.dart';

class BetterAuthCallAdapter<T>
    extends CallAdapter<Future<HttpResponse<T>>, Future<Result<T>>> {
  @override
  Future<Result<T>> adapt(Future<HttpResponse<T>> Function() call) async {
    try {
      final httpResponse = await call();
      final data = httpResponse.data;
      return Result<T>.ok(data);
    } on DioException catch (e, s) {
      final res = e.response;
      final status = res?.statusCode;
      final body = res?.data;
      StoneLogger.info('Dio response headers: ${res?.headers}', 'better_auth');
      StoneLogger.error('DioException: $e\nStack: $s', 'better_auth');
      StoneLogger.error('Status: $status, Body: $body', 'better_auth');
      return Result.err(
        BetterError(
          code: res?.data?['code'] ?? "ERROR",
          message: res?.data?['message'] ?? e.message,
          stack: s.toString(),
        ),
      );
    } catch (e, s) {
      StoneLogger.error('Unknown Error: $e\nStack: $s', 'better_auth');
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }
}
