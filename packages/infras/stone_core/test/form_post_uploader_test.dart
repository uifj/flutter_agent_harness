/// FormPostUploader 测试：本地 HttpServer 验证表单字段契约与错误映射。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_core/network_core.dart';

void main() {
  late HttpServer server;
  late String endpoint;
  late List<String> receivedBodies;
  int statusCode = 200;

  setUp(() async {
    receivedBodies = [];
    statusCode = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = 'localhost:${server.port}';
    server.listen((req) async {
      final body = await utf8DecodeSafe(req);
      receivedBodies.add(body);
      req.response.statusCode = statusCode;
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  // 测试用 dio 指向 http（生产走 https；用 baseUrl 改写协议不可行，
  // 因 upload 内部拼 'https://$endpoint' —— 这里经拦截器降级到本地）。
  Dio buildDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.path = options.path.replaceFirst('https://', 'http://');
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  OssFormUploadRequest request({String? filePath, Uint8List? bytes}) =>
      OssFormUploadRequest(
        endpoint: endpoint,
        objectKey: 'LOG/uuid/wuying-abc.zip',
        policy: 'policy-x',
        accessKeyId: 'ak-x',
        signature: 'sig-x',
        filePath: filePath,
        fileBytes: bytes,
      );

  test('表单字段契约逐字保真（key/policy/OSSAccessKeyId/'
      'success_action_status/signature/file）', () async {
    final uploader = FormPostUploader(dio: buildDio());
    final result = await uploader.upload(
      request(bytes: Uint8List.fromList([1, 2, 3])),
    );

    expect(result.isSuccess, isTrue);
    final body = receivedBodies.single;
    expect(body, contains('name="key"'));
    expect(body, contains('LOG/uuid/wuying-abc.zip'));
    expect(body, contains('name="policy"'));
    expect(body, contains('policy-x'));
    expect(body, contains('name="OSSAccessKeyId"'));
    expect(body, contains('name="success_action_status"'));
    expect(body, contains('200'));
    expect(body, contains('name="signature"'));
    expect(body, contains('name="file"'));
  });

  test('文件路径上传 + 进度回调', () async {
    final tmp = File(
      '${Directory.systemTemp.path}/form_post_test_${DateTime.now().microsecondsSinceEpoch}.bin',
    )..writeAsBytesSync(List.filled(2048, 7));
    addTearDown(tmp.deleteSync);

    var progressed = false;
    final uploader = FormPostUploader(dio: buildDio());
    final result = await uploader.upload(
      request(filePath: tmp.path),
      onProgress: (sent, total) => progressed = sent > 0,
    );

    expect(result.isSuccess, isTrue);
    expect(progressed, isTrue);
  });

  test('非 200 → HTTP_ERROR（server Failure）', () async {
    statusCode = 403;
    final uploader = FormPostUploader(dio: buildDio());
    final result = await uploader.upload(
      request(bytes: Uint8List.fromList([1])),
    );

    expect(result.isFailure, isTrue);
    expect(result.failure!.code, 'HTTP_ERROR');
    expect(result.failure!.statusCode, 403);
  });

  test('文件不存在 → input Failure（不发请求）', () async {
    final uploader = FormPostUploader(dio: buildDio());
    final result = await uploader.upload(
      request(filePath: '/no/such/file.bin'),
    );

    expect(result.isFailure, isTrue);
    expect(result.failure!.type, FailureType.validation);
    expect(receivedBodies, isEmpty);
  });

  test('dispose 后 upload → input Failure（不发请求）；dispose 幂等', () async {
    final uploader = FormPostUploader(dio: buildDio());
    uploader.dispose();
    uploader.dispose(); // 幂等

    final result = await uploader.upload(
      request(bytes: Uint8List.fromList([1])),
    );

    expect(result.isFailure, isTrue);
    expect(result.failure!.type, FailureType.validation);
    expect(receivedBodies, isEmpty);
  });

  test('取消 → REQUEST_CANCELLED', () async {
    final token = CancelToken()..cancel();
    final uploader = FormPostUploader(dio: buildDio());
    final result = await uploader.upload(
      request(bytes: Uint8List.fromList([1])),
      cancelToken: token,
    );

    expect(result.isFailure, isTrue);
    expect(result.failure!.code, 'REQUEST_CANCELLED');
  });
}

/// 读取请求体（multipart 含二进制段，容错解码）。
Future<String> utf8DecodeSafe(HttpRequest req) async {
  final bytes = <int>[];
  await for (final chunk in req) {
    bytes.addAll(chunk);
  }
  return String.fromCharCodes(bytes);
}
