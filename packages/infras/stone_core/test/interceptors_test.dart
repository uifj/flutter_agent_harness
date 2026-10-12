/// 拦截器与错误模型单元测试（零真实网络）。
///
/// 覆盖：HostInterceptor 专有云 host→IP 替换（映射命中/未命中/来源合并/
/// Host 头保留/异常兜底）、RequestError.fromDio 类型映射矩阵、
/// EnvEntity hosts 序列化往返。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_core/network_core.dart';

void main() {
  group('HostInterceptor（专有云 host→IP 替换）', () {
    late HttpManager manager;

    setUpAll(() async {
      manager = HttpManager.getInstance();
      // config 未注入时 initHostMap 置空表并 complete；随后注入测试映射。
      await manager.initHostMap();
      manager.setHosts({'gw.apsara.local': '10.0.0.8'});
      manager.setEndpointMap({
        'dns': EnvEntity.fromJson(const {
          'hosts': {
            'dns.apsara.local': '10.0.0.9',
            // 与 hostMap 同 key：endpoint 内嵌 DNS 覆盖优先。
            'gw.apsara.local': '10.0.0.99',
          },
        }),
      });
    });

    Future<RequestOptions> run(
      String url, {
      Map<String, dynamic>? headers,
    }) async {
      final options = RequestOptions(path: url, headers: headers);
      await HostInterceptor().onRequest(options, RequestInterceptorHandler());
      return options;
    }

    test('命中 hostMap（被 dns 覆盖）→ 替换为覆盖 IP 且原 host 进 Host 头', () async {
      final options = await run('https://gw.apsara.local/api/v1?x=1');

      expect(options.uri.host, '10.0.0.99', reason: 'dns 覆盖优先于 hostMap');
      expect(options.uri.path, '/api/v1');
      expect(options.uri.query, 'x=1');
      expect(options.headers['host'], 'gw.apsara.local');
    });

    test('命中 endpointMap[dns].hosts → 替换', () async {
      final options = await run('https://dns.apsara.local/ping');

      expect(options.uri.host, '10.0.0.9');
      expect(options.headers['host'], 'dns.apsara.local');
    });

    test('未命中映射 → 请求原样放行，不加 Host 头', () async {
      final options = await run('https://public.example.com/api');

      expect(options.uri.host, 'public.example.com');
      expect(options.headers.containsKey('host'), isFalse);
    });

    test('调用方已显式设置 Host 头时不覆盖', () async {
      final options = await run(
        'https://gw.apsara.local/api',
        headers: {'host': 'custom.example.com'},
      );

      expect(options.uri.host, '10.0.0.99');
      expect(options.headers['host'], 'custom.example.com');
    });
  });

  group('RequestError.fromDio 类型映射', () {
    DioException dioError(
      DioExceptionType type, {
      Object? error,
      Response<dynamic>? response,
    }) => DioException(
      requestOptions: RequestOptions(path: '/probe'),
      type: type,
      error: error,
      response: response,
    );

    test('三类超时 → TIMEOUT', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          RequestError.fromDio(dioError(type)).type,
          RequestErrorType.TIMEOUT,
          reason: '$type 应映射为 TIMEOUT',
        );
      }
    });

    test('cancel → CANCEL；badResponse → SERVER_ERROR（带状态码与 RequestId）', () {
      expect(
        RequestError.fromDio(dioError(DioExceptionType.cancel)).type,
        RequestErrorType.CANCEL,
      );

      final err = RequestError.fromDio(
        dioError(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 502,
            data: {'RequestId': 'req-1'},
          ),
        ),
        path: '/probe',
      );
      expect(err.type, RequestErrorType.SERVER_ERROR);
      expect(err.code, '502');
      expect(err.requestId, 'req-1');
      expect(err.path, '/probe');
    });

    test(
      'connectionError/badCertificate/Socket → NETWORK_ERROR，其余 unknown → UNKNOWN',
      () {
        expect(
          RequestError.fromDio(dioError(DioExceptionType.connectionError)).type,
          RequestErrorType.NETWORK_ERROR,
        );
        expect(
          RequestError.fromDio(dioError(DioExceptionType.badCertificate)).type,
          RequestErrorType.NETWORK_ERROR,
        );
        expect(
          RequestError.fromDio(
            dioError(
              DioExceptionType.unknown,
              error: const SocketException('down'),
            ),
          ).type,
          RequestErrorType.NETWORK_ERROR,
        );
        expect(
          RequestError.fromDio(
            dioError(DioExceptionType.unknown, error: StateError('x')),
          ).type,
          RequestErrorType.UNKNOWN,
        );
      },
    );
  });

  group('EnvEntity', () {
    test('hosts 序列化往返不丢失', () {
      final entity = EnvEntity.fromJson(const {
        'hosts': {'a.local': '10.0.0.1'},
        'default': 'https://api.example.com',
      });

      final json = entity.toJson();
      expect(json['hosts'], {'a.local': '10.0.0.1'});
      expect(EnvEntity.fromJson(json.cast<String, dynamic>()).hosts, {
        'a.local': '10.0.0.1',
      });
    });
  });
}
