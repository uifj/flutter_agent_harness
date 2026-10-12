/// NetworkCacheInterceptor 测试：五策略 + LRU 淘汰 + TTL 过期。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_core/network_core.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  int hits = 0;

  Options withPolicy(CachePolicy policy, {Duration? ttl}) =>
      Options(extra: {CacheExtraKeys.policy: policy, CacheExtraKeys.ttl: ?ttl});

  setUp(() async {
    hits = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      hits++;
      req.response.headers.contentType = ContentType.json;
      req.response.write('{"n": $hits}');
      await req.response.close();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:${server.port}'));
    dio.interceptors.add(NetworkCacheInterceptor());
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
  });

  test('缺省（onlyNetwork）完全旁路：每次都走网络、不写缓存', () async {
    await dio.get<dynamic>('/a');
    final second = await dio.get<dynamic>('/a');
    expect(hits, 2);
    expect((second.data as Map)['n'], 2);
  });

  test('cacheFirst：命中未过期缓存直接短路，不发第二次请求', () async {
    final first = await dio.get<dynamic>(
      '/a',
      options: withPolicy(CachePolicy.cacheFirst),
    );
    final second = await dio.get<dynamic>(
      '/a',
      options: withPolicy(CachePolicy.cacheFirst),
    );
    expect(hits, 1, reason: '第二次命中缓存短路');
    expect((second.data as Map)['n'], (first.data as Map)['n']);
  });

  test('onlyCache：未命中 reject', () async {
    await expectLater(
      dio.get<dynamic>('/miss', options: withPolicy(CachePolicy.onlyCache)),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          'no cache available',
        ),
      ),
    );
    expect(hits, 0);
  });

  test('networkFirst：网络失败降级读缓存（过期条目也兜底）', () async {
    // 先以极短 TTL 写入缓存。
    await dio.get<dynamic>(
      '/a',
      options: withPolicy(
        CachePolicy.networkFirst,
        ttl: const Duration(milliseconds: 1),
      ),
    );
    expect(hits, 1);
    await Future<void>.delayed(const Duration(milliseconds: 10)); // 使过期
    await server.close(force: true); // 断网

    final fallback = await dio.get<dynamic>(
      '/a',
      options: withPolicy(CachePolicy.networkFirst),
    );
    expect((fallback.data as Map)['n'], 1, reason: '断网返回过期缓存兜底');
  });

  test('cacheThenNetwork：stale 进 extra，同时网络刷新', () async {
    await dio.get<dynamic>(
      '/a',
      options: withPolicy(CachePolicy.cacheThenNetwork),
    );
    final second = await dio.get<dynamic>(
      '/a',
      options: withPolicy(CachePolicy.cacheThenNetwork),
    );
    expect(hits, 2, reason: '缓存命中不短路，仍走网络刷新');
    final stale =
        second.requestOptions.extra[CacheExtraKeys.staleResponse]
            as Response<dynamic>?;
    expect(stale, isNotNull);
    expect((stale!.data as Map)['n'], 1, reason: 'stale 是上一次的响应');
    expect((second.data as Map)['n'], 2);
  });

  test('buildCacheKey：不同 body 不同 key；嵌套 Map 构造顺序不影响 key', () {
    RequestOptions opts(dynamic data) => RequestOptions(path: '/p', data: data);

    // 非 Map body 参与 key（早期实现退化为空串导致同 key 碰撞）。
    final k1 = NetworkCacheInterceptor.buildCacheKey(opts('body-a'));
    final k2 = NetworkCacheInterceptor.buildCacheKey(opts('body-b'));
    expect(k1, isNot(k2));

    final f1 = NetworkCacheInterceptor.buildCacheKey(
      opts(FormData.fromMap({'x': '1'})),
    );
    final f2 = NetworkCacheInterceptor.buildCacheKey(
      opts(FormData.fromMap({'x': '2'})),
    );
    expect(f1, isNot(f2));

    // 嵌套 Map 键序稳定：构造顺序不同 → 同 key。
    final m1 = NetworkCacheInterceptor.buildCacheKey(
      opts({
        'b': {'y': 2, 'x': 1},
        'a': [1, 2],
      }),
    );
    final m2 = NetworkCacheInterceptor.buildCacheKey(
      opts({
        'a': [1, 2],
        'b': {'x': 1, 'y': 2},
      }),
    );
    expect(m1, m2);
  });

  test('MemoryLruCacheStore：容量淘汰最久未使用', () async {
    final store = MemoryLruCacheStore(capacity: 2);
    HttpCacheEntry entry(String v) => HttpCacheEntry(
      data: v,
      savedAt: DateTime.now(),
      ttl: const Duration(minutes: 1),
    );
    await store.put('a', entry('a'));
    await store.put('b', entry('b'));
    await store.get('a'); // a 变为最近使用
    await store.put('c', entry('c')); // 淘汰 b
    expect(await store.get('a'), isNotNull);
    expect(await store.get('b'), isNull);
    expect(await store.get('c'), isNotNull);
    expect(store.length, 2);
  });

  test('TTL 过期语义 + cacheFirst 过期后回源', () async {
    final expired = HttpCacheEntry(
      data: 'x',
      savedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ttl: const Duration(minutes: 5),
    );
    expect(expired.isExpired, isTrue);

    await dio.get<dynamic>(
      '/a',
      options: withPolicy(
        CachePolicy.cacheFirst,
        ttl: const Duration(milliseconds: 1),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await dio.get<dynamic>('/a', options: withPolicy(CachePolicy.cacheFirst));
    expect(hits, 2, reason: '过期缓存不短路，回源网络');
  });
}
