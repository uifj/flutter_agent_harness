import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../../logger/logger_core.dart';

import '../network_abstractions.dart';
import '../refresh_login_model.dart';

/// Error codes that indicate the user needs to re-login.
const _kLogoutCodes = [
  'post_resources_failed',
  'consoleneedlogin',
  'not_login',
  'postonlyortokenerror',
  'authorize_failed',
  'invalid_csrf_token',
  'missinglogintoken',
  'user.logininvalid',
  'userinvalidexception',
];

/// Actions that should NOT be intercepted for token refresh.
const _kActionList = ['GetLoginToken', 'GetLoginTokenByKeepAlive'];

/// Interceptor that handles login token expiration by refreshing
/// the token via the KeepAlive mechanism.
class RefreshLoginInterceptor extends InterceptorsWrapper {
  RefreshLoginModel? _refreshLoginModel;
  Completer<bool>? _refreshTokenCompleter;
  int? _loginModelHashCode;

  RefreshLoginInterceptor({RefreshLoginModel? refreshLoginModel}) {
    _refreshLoginModel = refreshLoginModel;
  }

  void setRefreshLoginModel(RefreshLoginModel? model) {
    _refreshLoginModel = model;
    _loginModelHashCode = model?.hashCode;
  }

  /// Re-authenticates using the KeepAlive token for enterprise accounts.
  Future<Map<String, dynamic>> loginForVerifyKeepAlive(
    String? companyId,
    String keepAliveToken, {
    CancelToken? cancelToken,
    bool keepAlive = false,
    String? idpId,
  }) async {
    final serviceBase = NetworkServiceLocator.serviceBase;
    final application = NetworkServiceLocator.application;

    String regionId = '';
    final bool isOldLogin =
        _refreshLoginModel?.officeSiteId?.contains('+dir-') ?? false;
    final bool isApsara = _refreshLoginModel?.apsara ?? false;
    if (!isApsara && isOldLogin) {
      regionId = _refreshLoginModel!.officeSiteId!.split('+dir-')[0];
    }
    final String deviceName = await application?.getDeviceName() ?? '';
    final param = {
      'Action': 'GetLoginToken',
      'CurrentStage': 'KeepAliveVerify',
      'OfficeSiteId': companyId,
      'KeepAliveToken': keepAliveToken,
      'KeepAlive': keepAlive,
      'RegionId': regionId,
      'SessionId': '',
      'ClientName': deviceName,
      'AutoRefresh': true,
      ...?_refreshLoginModel?.baseParams,
    };
    if (idpId != null && idpId.isNotEmpty) {
      param['IdpId'] = idpId;
    }
    param['AvailableFeatures'] = json.encode({'supportStandardErrorCode': '1'});

    Map<String, dynamic> loginModel;
    if (isOldLogin && serviceBase != null) {
      loginModel = await serviceBase.ecdRequest(
        param,
        (jsonStr) => jsonStr is Map<String, dynamic>
            ? jsonStr
            : json.decode(jsonStr as String) as Map<String, dynamic>,
        regionId: regionId,
        version: param['Version'] as String?,
        traceId: _refreshLoginModel?.traceId,
        spanId: _refreshLoginModel?.spanId,
      );
    } else if (serviceBase != null) {
      loginModel = await serviceBase.appStreamRequest(
        param,
        (jsonStr) => jsonStr is Map<String, dynamic>
            ? jsonStr
            : json.decode(jsonStr as String) as Map<String, dynamic>,
        version: param['Version'] as String?,
        traceId: _refreshLoginModel?.traceId,
        spanId: _refreshLoginModel?.spanId,
        supportIntlBeforeLogin: true,
      );
      // 写缓存不阻塞登录链路（legacy 行为），显式标注 fire-and-forget。
      unawaited(
        NetworkServiceLocator.config?.setSecure(
          'login.regionId',
          serviceBase.getDowngradeRegionId('Login'),
        ),
      );
    } else {
      throw StateError('ServiceBaseInterface not initialized');
    }
    return loginModel;
  }

  /// Re-authenticates for personal accounts.
  Future<Map<String, dynamic>> personalForVerifyKeepAlive(
    String? keepAliveToken,
  ) async {
    final serviceBase = NetworkServiceLocator.serviceBase;
    final application = NetworkServiceLocator.application;
    if (serviceBase == null) {
      throw StateError('ServiceBaseInterface not initialized');
    }

    final String deviceName = await application?.getDeviceName() ?? '';
    final param = {
      'Action': 'GetLoginTokenByKeepAlive',
      'KeepAliveToken': keepAliveToken,
      'EndUserId': '',
      'SessionId': '',
      'Brand': _refreshLoginModel?.brand,
      'Model': _refreshLoginModel?.model,
      'SupportAliyunId': true,
      'AutoRefresh': true,
      'ClientName': deviceName,
    };
    param['AvailableFeatures'] = json.encode({'supportStandardErrorCode': '1'});

    return await serviceBase.appStreamRequest(
      param,
      (jsonStr) => jsonStr is Map<String, dynamic>
          ? jsonStr
          : json.decode(jsonStr as String) as Map<String, dynamic>,
      version: '2022-11-22',
      traceId: _refreshLoginModel?.traceId,
      spanId: _refreshLoginModel?.spanId,
    );
  }

  /// Re-sends the intercepted request with a fresh login token.
  Future<Response<dynamic>> getNewResponse(
    RequestOptions requestOptions,
  ) async {
    final globalStore = NetworkServiceLocator.globalStore;
    final serviceBase = NetworkServiceLocator.serviceBase;
    if (globalStore == null || serviceBase == null) {
      throw StateError('Required services not initialized');
    }

    final body = SplayTreeMap<String, dynamic>();
    body.addAll(requestOptions.data as Map<String, dynamic>);
    body.remove('SignatureNonce');
    await serviceBase.signature(
      body,
      customSignature: body.containsKey('CustomSignature'),
    );

    body['LoginToken'] = globalStore.loginToken;
    if (body.containsKey('SessionId')) {
      body['SessionId'] = globalStore.sessionId;
    }
    StoneLogger.info('Retry request method: ${requestOptions.method}', 'Net');

    final response = await _dioRequest(
      requestOptions.uri.toString(),
      data: body,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: {'notLoginRetryRequest': 1, ...requestOptions.extra},
        headers: requestOptions.headers,
        responseType: requestOptions.responseType,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
      ),
    );
    return response;
  }

  Future<Response<dynamic>> _dioRequest(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final dio = Dio();
    return dio.request<dynamic>(
      path,
      data: data,
      cancelToken: cancelToken,
      options: options,
    );
  }

  bool _handleRefreshCancel() {
    final globalStore = NetworkServiceLocator.globalStore;
    if (globalStore == null ||
        globalStore.loginToken.isEmpty ||
        _refreshLoginModel == null ||
        _loginModelHashCode != _refreshLoginModel?.hashCode) {
      StoneLogger.info(
        'RefreshLoginInterceptor is canceled because refreshLoginModel has changed or logout.',
        'Net',
      );
      return true;
    }
    return false;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    _loginModelHashCode = _refreshLoginModel?.hashCode;

    // 非 Map body（FormData/List/String）不做刷新逻辑，直接透传
    //（legacy 强 cast 会抛 TypeError 打断错误流）。
    final data = err.requestOptions.data;
    if (data is! Map<String, dynamic>) {
      handler.next(err);
      return;
    }
    final Map<String, dynamic> requestData = data;

    // Filter: don't intercept certain actions or already-retried requests
    if (!_kActionList.contains(requestData['Action']) &&
        err.requestOptions.extra['notLoginRetryRequest'] != 1 &&
        _refreshLoginModel != null &&
        err.error is RequestError) {
      final RequestError error = err.error as RequestError;
      if (error.type == RequestErrorType.SERVER_ERROR &&
          _kLogoutCodes.contains(error.code?.toLowerCase())) {
        // Ensure only one request is processed at a time
        if (_refreshTokenCompleter == null) {
          final requestOptions = err.requestOptions;

          if (requestData['LoginToken'] ==
              NetworkServiceLocator.globalStore?.loginToken) {
            _refreshTokenCompleter = Completer();

            try {
              // cancel 时必须透传原错误收尾拦截器链
              //（legacy 直接 return 会使调用方 Future 永久挂起）。
              if (_handleRefreshCancel()) {
                handler.next(err);
                return;
              }

              Map<String, dynamic> loginModel;
              final globalStore = NetworkServiceLocator.globalStore;
              if (globalStore == null) {
                handler.next(err);
                return;
              }

              if (globalStore.isPersonal) {
                final model = await personalForVerifyKeepAlive(
                  _refreshLoginModel!.keepAliveToken,
                );
                loginModel = model;
              } else {
                final String? profileRegion = await NetworkServiceLocator.config
                    ?.getSecure('ro.sd.profileRegion');
                if (NetworkServiceLocator.serviceBase != null) {
                  NetworkServiceLocator.serviceBase!.internationality =
                      ('ap_southeast_1' == profileRegion);
                }
                loginModel = await loginForVerifyKeepAlive(
                  _refreshLoginModel!.officeSiteId,
                  _refreshLoginModel!.keepAliveToken!,
                  keepAlive: true,
                  idpId: _refreshLoginModel!.idpId,
                );
              }

              if (NetworkServiceLocator.serviceBase != null) {
                NetworkServiceLocator.serviceBase!.internationality =
                    // 保持 legacy dynamic 访问语义（props 非 Map 时异常进外层 catch）。
                    // ignore: avoid_dynamic_calls
                    ('ap_southeast_1' == loginModel['props']?['profileRegion']);
              }

              if (!_handleRefreshCancel()) {
                // Update keepAliveToken
                final keepAliveToken = loginModel['keepAliveToken'] as String?;
                if (keepAliveToken != null && keepAliveToken.isNotEmpty) {
                  _refreshLoginModel!.keepAliveToken = keepAliveToken;
                  await NetworkServiceLocator.config?.setSecure(
                    'ro.sd.keepAliveToken',
                    keepAliveToken,
                  );
                }

                // Update login state
                await globalStore.saveStore(
                  tenantId: (loginModel['tenantId'] ?? '').toString(),
                  loginToken: loginModel['loginToken'] as String? ?? '',
                  sessionId: loginModel['sessionId'] as String? ?? '',
                );
                StoneLogger.info(
                  'RefreshLoginTokenInterceptor onRequest success',
                  'Net',
                );
              }
              _refreshTokenCompleter!.complete(true);
            } catch (e) {
              NetworkServiceLocator.functionTracer?.addTrace(
                'LoginTokenInterceptor',
                detail:
                    'LoginTokenInterceptor: getLoginToken by keepAliveToken error',
                error: e.toString(),
              );
              StoneLogger.error(
                'RefreshLoginInterceptor getLoginToken by keepAliveToken error : $e',
                'Net',
              );
              _refreshTokenCompleter!.complete(false);
              handler.next(err);
              return;
            } finally {
              if (!_refreshTokenCompleter!.isCompleted) {
                _refreshTokenCompleter!.complete(false);
              }
              _refreshTokenCompleter = null;
            }

            // Retry the current intercepted request
            try {
              // cancel 时必须透传原错误收尾拦截器链
              //（legacy 直接 return 会使调用方 Future 永久挂起）。
              if (_handleRefreshCancel()) {
                handler.next(err);
                return;
              }
              final response = await getNewResponse(requestOptions);
              handler.resolve(response);
              return;
            } catch (e) {
              NetworkServiceLocator.functionTracer?.addTrace(
                'LoginTokenInterceptor',
                detail: 'LoginTokenInterceptor: current request retry error',
                error: e.toString(),
              );
              StoneLogger.error(
                'RefreshLoginInterceptor current request retry error : $e',
                'Net',
              );
            }
          } else {
            // Login token already refreshed, just retry
            try {
              // cancel 时必须透传原错误收尾拦截器链
              //（legacy 直接 return 会使调用方 Future 永久挂起）。
              if (_handleRefreshCancel()) {
                handler.next(err);
                return;
              }
              final response = await getNewResponse(requestOptions);
              handler.resolve(response);
              return;
            } catch (e) {
              StoneLogger.error(
                'RefreshLoginInterceptor retry after refresh error: $e',
                'Net',
              );
            }
          }
        } else {
          // Wait for the ongoing refresh to complete, then retry
          try {
            if (_handleRefreshCancel()) {
              handler.next(err);
              return;
            }
            final bool isSuccess = await _refreshTokenCompleter!.future;
            if (!isSuccess) {
              handler.next(err);
              return;
            }
            final response = await getNewResponse(err.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            NetworkServiceLocator.functionTracer?.addTrace(
              'LoginTokenInterceptor',
              detail: 'LoginTokenInterceptor: request retry error',
              error: e.toString(),
            );
            StoneLogger.error(
              'RefreshLoginInterceptor request retry error : $e',
              'Net',
            );
          }
        }
      }
    }
    handler.next(err);
  }
}
