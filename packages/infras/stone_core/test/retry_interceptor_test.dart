/// RetryInterceptor 测试：重试行为 + 计数泄漏回归守卫
///（早期实现把 retry_attempt 写进 headers 随请求发往服务端）。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_core/network_core.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late List<Map<String, String>> receivedHeaders;
  int hangTimes = 0; // 前 N 次请求挂起以触发 receiveTimeout。

  setUp(() async {
    receivedHeaders = [];
    hangTimes = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final headers = <String, String>{};
      req.headers.forEach((name, values) => headers[name] = values.join(','));
      receivedHeaders.add(headers);
      if (receivedHeaders.length <= hangTimes) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      req.response.write('ok');
      await req.response.close();
    });
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:${server.port}',
        receiveTimeout: const Duration(seconds: 1),
      ),
    );
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
      ),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
  });

  test('超时触发重试并最终成功；请求头中不含 retry_attempt', () async {
    hangTimes = 1; // 首次挂起超时，第二次成功。
    final response = await dio.get<String>('/x');

    expect(response.data, 'ok');
    expect(receivedHeaders, hasLength(2), reason: '原始 1 次 + 重试 1 次');
    for (final headers in receivedHeaders) {
      expect(
        headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('retry_attempt')),
        reason: '重试计数是内部元数据，不得泄漏到 HTTP 请求头',
      );
    }
  });

  test('重试次数受 maxRetries/延迟表约束（全部超时 → 共 4 次请求后失败）', () async {
    hangTimes = 99;
    await expectLater(dio.get<String>('/x'), throwsA(isA<DioException>()));
    // 原始 1 次 + 3 次重试。
    expect(receivedHeaders, hasLength(4));
  });
}
