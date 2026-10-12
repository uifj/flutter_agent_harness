import 'package:dio/dio.dart';

import '../../core/api/models/session/session_response.dart';
import '../../core/api/models/result/better_error.dart';
import '../../core/api/models/result/result.dart';
import '../../core/api/models/result/status_response.dart';
import 'models/passkey_record.dart';
import 'models/passkey_update_response.dart';

String _combinePasskeyBaseUrls(String dioBaseUrl, String? baseUrl) {
  if (baseUrl == null || baseUrl.trim().isEmpty) {
    return dioBaseUrl;
  }
  final url = Uri.parse(baseUrl);
  if (url.isAbsolute) {
    return url.toString();
  }
  return Uri.parse(dioBaseUrl).resolveUri(url).toString();
}

Result<R> _passkeyErr<R>(Object e, StackTrace s, DioException? de) {
  final res = de?.response;
  final raw = res?.data;
  return Result<R>.err(
    BetterError(
      code: raw is Map && raw['code'] is String
          ? raw['code'] as String
          : 'ERROR',
      message: raw is Map && raw['message'] is String
          ? raw['message'] as String
          : (de?.message ?? e.toString()),
      stack: s.toString(),
    ),
  );
}

Options _jsonOptions(Dio dio) => Options(
  contentType: Headers.jsonContentType,
  headers: dio.options.headers,
  validateStatus: dio.options.validateStatus,
  responseType: ResponseType.json,
);

String _normalizedApiRoot(Dio dio, String? baseUrl) {
  final composed = _combinePasskeyBaseUrls(dio.options.baseUrl, baseUrl);
  if (composed.endsWith('/')) {
    return composed.substring(0, composed.length - 1);
  }
  return composed;
}

/// Better Auth [`passkey`](https://www.better-auth.com/docs/plugins/passkey).
///
/// Mirrors the Better Auth TS client's **two-step** WebAuthn flow
/// ([`client.ts`](https://github.com/better-auth/better-auth/blob/main/packages/passkey/src/client.ts)):
/// 1. `generateRegistrationOptions` → WebAuthn `create`; `verifyRegistration(body: ...)`
/// 2. `generateAuthenticationOptions` → WebAuthn `get`; `verifyAuthentication(body: ...)`
///
/// Combine with [`passkeys`](https://pub.dev/packages/passkeys) or platform Web APIs for the ceremony.
class PasskeyBetterAuth {
  PasskeyBetterAuth(this._dio, {String? baseUrl}) : _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  String get _root => _normalizedApiRoot(_dio, _baseUrl);

  /// **`GET /passkey/generate-register-options`**
  Future<Result<Map<String, dynamic>>> generateRegistrationOptions({
    String? name,
    String? authenticatorAttachment,
    String? context,
  }) async {
    final qp = <String, dynamic>{
      'name': ?name,
      'authenticatorAttachment': ?authenticatorAttachment,
      'context': ?context,
    };
    try {
      final response = await _dio.get<Map<String, dynamic>?>(
        '$_root/passkey/generate-register-options',
        queryParameters: qp.isEmpty ? null : qp,
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(
            message: 'Empty registration options response',
            stack: '',
          ),
        );
      }
      return Result.ok(data);
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`POST /passkey/verify-registration`**
  ///
  /// Body must contain `response` (`RegistrationResponseJSON` from [@simplewebauthn](https://pub.dev/packages/webauthn))
  /// and optional `name`.
  Future<Result<PasskeyRecord>> verifyRegistration(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>?>(
        '$_root/passkey/verify-registration',
        data: body,
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(message: 'Empty verify-registration response', stack: ''),
        );
      }
      return Result.ok(PasskeyRecord.fromJson(data));
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`GET /passkey/generate-authenticate-options`**
  Future<Result<Map<String, dynamic>>> generateAuthenticationOptions() async {
    try {
      final response = await _dio.get<Map<String, dynamic>?>(
        '$_root/passkey/generate-authenticate-options',
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(
            message: 'Empty authentication options response',
            stack: '',
          ),
        );
      }
      return Result.ok(data);
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`POST /passkey/verify-authentication`** — sets session on success.
  ///
  /// Body must contain `response` (`AuthenticationResponseJSON`).
  Future<Result<SessionResponse>> verifyAuthentication(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>?>(
        '$_root/passkey/verify-authentication',
        data: body,
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(
            message: 'Empty verify-authentication response',
            stack: '',
          ),
        );
      }
      return Result.ok(SessionResponse.fromJson(data));
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`GET /passkey/list-user-passkeys`**
  Future<Result<List<PasskeyRecord>>> listUserPasskeys() async {
    try {
      final response = await _dio.get<Object?>(
        '$_root/passkey/list-user-passkeys',
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data is! List) {
        return Result.err(
          BetterError(message: 'Expected passkey array', stack: ''),
        );
      }
      final list = data
          .map((e) => PasskeyRecord.fromJson(_asMap(e)))
          .toList(growable: false);
      return Result.ok(list);
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`POST /passkey/delete-passkey`**
  Future<Result<StatusResponse>> deletePasskey({required String id}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>?>(
        '$_root/passkey/delete-passkey',
        data: <String, dynamic>{'id': id},
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(message: 'Empty delete-passkey response', stack: ''),
        );
      }
      return Result.ok(StatusResponse.fromJson(data));
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }

  /// **`POST /passkey/update-passkey`**
  Future<Result<PasskeyUpdateResponse>> updatePasskey({
    required String id,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>?>(
        '$_root/passkey/update-passkey',
        data: <String, dynamic>{'id': id, 'name': name},
        options: _jsonOptions(_dio),
      );
      final data = response.data;
      if (data == null) {
        return Result.err(
          BetterError(message: 'Empty update-passkey response', stack: ''),
        );
      }
      return Result.ok(PasskeyUpdateResponse.fromJson(data));
    } on DioException catch (e, s) {
      return _passkeyErr(e, s, e);
    } catch (e, s) {
      return Result.err(
        BetterError(message: e.toString(), stack: s.toString()),
      );
    }
  }
}

Map<String, dynamic> _asMap(Object? e) {
  if (e is Map<String, dynamic>) {
    return e;
  }
  if (e is Map) {
    return Map<String, dynamic>.from(e);
  }
  throw FormatException('Passkey JSON object expected, got ${e.runtimeType}');
}
