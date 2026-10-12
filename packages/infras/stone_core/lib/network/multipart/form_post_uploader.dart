/// OSS PostObject 表单直传（凭证由调用方注入）。
///
/// 行为规格来源（legacy）：pudding `report_issue_service.dart`
/// `uploadFile`（L305-364）/`uploadDir`（L238-302）—— 反馈附件、日志 zip、
/// 截图均走 OSS 表单 POST（policy/signature 预签名），与分片引擎
/// [MultipartUploader] 互补（小文件一把梭 vs 大文件分片）。
///
/// 表单字段逐字保真：key / policy / OSSAccessKeyId /
/// success_action_status='200' / signature / file。
/// 改造点：代理与自签证书策略属宿主网络栈（构造注入 Dio），
/// legacy 每次上传新建并 close Dio 的低效模式收敛为实例复用。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../logger/logger_core.dart';
import '../result.dart';

const String _tag = 'Net';

/// 单次表单直传请求。
class OssFormUploadRequest {
  const OssFormUploadRequest({
    required this.endpoint,
    required this.objectKey,
    required this.policy,
    required this.accessKeyId,
    required this.signature,
    this.filePath,
    this.fileBytes,
  }) : assert(
         filePath != null || fileBytes != null,
         'either filePath or fileBytes is required',
       );

  /// OSS endpoint host（不含 scheme；与 legacy `'https://$url'` 拼接一致）。
  final String endpoint;

  /// 对象键（同时用作 multipart filename，legacy L318）。
  final String objectKey;

  /// PostObject 预签名三件套（业务层经 GetFbOssConfig 等接口获取）。
  final String policy;
  final String accessKeyId;
  final String signature;

  /// 本地文件路径；与 [fileBytes] 二选一（bytes 优先，legacy L311-314）。
  final String? filePath;

  /// 内存内容（web 端日志等无文件场景）。
  final Uint8List? fileBytes;
}

/// OSS 表单直传器。
class FormPostUploader {
  /// 注入 [dio]（宿主代理/证书策略、测试 mock）；缺省自建裸实例。
  FormPostUploader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 120),
            ),
          ),
      _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  bool _disposed = false;

  /// 上传单个文件；成功条件为 HTTP 200（legacy L285/L348）。
  Future<Result<void>> upload(
    OssFormUploadRequest request, {
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_disposed) {
      return Result.failure(
        Failure.input(message: 'FormPostUploader has been disposed'),
      );
    }
    MultipartFile file;
    final bytes = request.fileBytes;
    if (bytes != null) {
      file = MultipartFile.fromBytes(bytes, filename: request.objectKey);
    } else {
      final path = request.filePath!;
      if (!File(path).existsSync()) {
        return Result.failure(
          Failure.input(message: 'file not existed: $path'),
        );
      }
      file = await MultipartFile.fromFile(path, filename: request.objectKey);
    }

    final form = FormData.fromMap(<String, dynamic>{
      'key': request.objectKey,
      'policy': request.policy,
      'OSSAccessKeyId': request.accessKeyId,
      'success_action_status': '200',
      'signature': request.signature,
      'file': file,
    });

    try {
      final response = await _dio.post<dynamic>(
        'https://${request.endpoint}',
        data: form,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) => onProgress?.call(sent, total),
      );
      if (response.statusCode == 200) return const Result.success(null);
      return Result.failure(
        Failure(
          code: 'HTTP_ERROR',
          message: 'form upload failed (HTTP ${response.statusCode})',
          type: FailureType.server,
          statusCode: response.statusCode,
        ),
      );
    } on DioException catch (e) {
      StoneLogger.error(
        '[formUpload] ${request.objectKey} failed: ${e.type}',
        _tag,
      );
      return Result.failure(_toFailure(e));
    }
  }

  /// 释放自建的 Dio（幂等；释放后 [upload] 返回 input Failure）。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsDio) _dio.close(force: true);
  }

  static Failure _toFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return Failure.timeout(message: 'Connection timeout');
      case DioExceptionType.cancel:
        return const Failure(
          code: 'REQUEST_CANCELLED',
          message: 'Request cancelled',
          type: FailureType.network,
        );
      case DioExceptionType.badResponse:
        return Failure(
          code: 'HTTP_ERROR',
          message: 'form upload failed (HTTP ${e.response?.statusCode})',
          type: FailureType.server,
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return Failure.network(message: 'No internet connection');
        }
        return Failure.server(message: 'form upload failed: ${e.message}');
    }
  }
}
