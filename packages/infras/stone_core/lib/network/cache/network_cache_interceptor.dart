/// HTTP 缓存拦截器（请求级 opt-in；不挂 HttpManager 默认链）。
///
/// 使用方式：
/// ```dart
/// dio.interceptors.add(NetworkCacheInterceptor());
/// final resp = await dio.get('/config', options: Options(extra: {
///   'cachePolicy': CachePolicy.cacheFirst,
///   'cacheTtl': const Duration(minutes: 30),
/// }));
/// ```
/// 建议挂载在鉴权拦截器之后（缓存命中即短路，无需等待 token 逻辑）。
///
/// 刻意不挂默认链：HttpManager 主链路是带签名（SignatureNonce）的
/// wyota 请求，缓存签名请求有重放语义风险，必须由调用方显式启用。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import '../../logger/logger_core.dart';

import 'http_cache.dart';

const String _tag = 'Net';

/// 请求 extra 键。
abstract final class CacheExtraKeys {
  static const policy = 'cachePolicy';
  static const ttl = 'cacheTtl';

  /// cacheThenNetwork 时旧缓存（`Response<dynamic>`）供调用方首屏消费。
  static const staleResponse = 'staleResponse';
}

/// 缓存拦截器。
class NetworkCacheInterceptor extends Interceptor {
  NetworkCacheInterceptor({
    HttpCacheStore? store,
    this.defaultTtl = const Duration(minutes: 5),
  }) : _store = store ?? MemoryLruCacheStore();

  final HttpCacheStore _store;
  final Duration defaultTtl;

  /// 缓存 key：method + path + 排序 query + body。
  ///（文章用 md5 定长化；本包不引入 crypto 依赖，长字符串 key 无碍。）
  ///
  /// query/body 均做稳定序列化（嵌套 Map 递归排序键），FormData 取
  /// 字段与文件名参与 key —— 避免"同 path 不同 body 同 key"的错误命中。
  static String buildCacheKey(RequestOptions options) {
    final sortedQuery = options.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final query = sortedQuery
        .map((e) => '${e.key}=${_stableEncode(e.value)}')
        .join('&');
    return '${options.method} ${options.uri.path}?$query '
        '${_bodyKeyPart(options.data)}';
  }

  static String _bodyKeyPart(dynamic data) {
    if (data == null) return '';
    if (data is FormData) {
      final parts = [
        ...data.fields.map((e) => '${e.key}=${e.value}'),
        ...data.files.map((e) => '${e.key}:${e.value.filename}'),
      ]..sort();
      return 'form(${parts.join('&')})';
    }
    return _stableEncode(data);
  }

  /// 稳定序列化：嵌套 Map 按键排序，构造顺序不影响 key。
  static String _stableEncode(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
      return '{${entries.map((e) => '"${e.key}":${_stableEncode(e.value)}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_stableEncode).join(',')}]';
    }
    return '$value';
  }

  CachePolicy _policyOf(RequestOptions options) =>
      options.extra[CacheExtraKeys.policy] as CachePolicy? ??
      CachePolicy.onlyNetwork;

  Duration _ttlOf(RequestOptions options) =>
      options.extra[CacheExtraKeys.ttl] as Duration? ?? defaultTtl;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final policy = _policyOf(options);
    if (policy == CachePolicy.onlyNetwork) return handler.next(options);

    try {
      final key = buildCacheKey(options);
      final cached = await _store.get(key);

      if (cached != null && !cached.isExpired) {
        if (policy == CachePolicy.cacheFirst ||
            policy == CachePolicy.onlyCache) {
          return handler.resolve(cached.toResponse(options), true);
        }
        if (policy == CachePolicy.cacheThenNetwork) {
          options.extra[CacheExtraKeys.staleResponse] = cached.toResponse(
            options,
          );
        }
      } else if (policy == CachePolicy.onlyCache) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: 'no cache available',
          ),
        );
      }
    } catch (e) {
      StoneLogger.error('CacheInterceptor onRequest error: $e', _tag);
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final policy = _policyOf(options);
    if (policy != CachePolicy.onlyNetwork && response.statusCode == 200) {
      final entry = HttpCacheEntry(
        data: response.data,
        statusCode: response.statusCode,
        savedAt: DateTime.now(),
        ttl: _ttlOf(options),
      );
      // 写缓存不阻塞响应返回（写失败仅记日志）。
      unawaited(
        _store.put(buildCacheKey(options), entry).catchError((Object e) {
          StoneLogger.error('CacheInterceptor put error: $e', _tag);
        }),
      );
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_policyOf(err.requestOptions) == CachePolicy.networkFirst) {
      try {
        final cached = await _store.get(buildCacheKey(err.requestOptions));
        if (cached != null) {
          // 网络失败兜底：过期条目也返回（文章 networkFirst 语义）。
          return handler.resolve(cached.toResponse(err.requestOptions));
        }
      } catch (e) {
        StoneLogger.error('CacheInterceptor onError fallback error: $e', _tag);
      }
    }
    handler.next(err);
  }
}
