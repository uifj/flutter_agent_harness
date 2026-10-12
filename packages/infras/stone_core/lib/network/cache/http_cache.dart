/// HTTP 缓存原语：策略枚举 / 缓存条目 / 存储端口 / 内存 LRU 默认实现。
///
/// 设计参考《Flutter Dio高阶封装&多级缓存策略》的多级缓存方案，
/// 按本仓分层适配：
/// - L1 内存 LRU 内置（自实现，不依赖 storage_core —— 该包 Phase 10
///   已并入 stone，反向依赖会成环）；
/// - L2 磁盘层经 [HttpCacheStore] 端口出让宿主（Hive/SQLite 属上层选型，
///   与 upgrade/file_transfer 的端口化模式一致）。
library;

import 'package:dio/dio.dart';

/// 缓存策略（语义保真参考文章，场景对照）：
///
/// | 策略             | 场景               | 一致性        |
/// |------------------|--------------------|---------------|
/// | onlyNetwork      | 支付/下单/提交表单 | 强一致        |
/// | cacheFirst       | 配置/城市/字典表   | TTL 内弱一致  |
/// | networkFirst     | 详情/个人信息      | 较强，弱网兜底|
/// | cacheThenNetwork | 首页信息流（SWR）  | 最终一致      |
/// | onlyCache        | 离线模式           | 依赖新鲜度    |
enum CachePolicy {
  /// 只走网络，不读不写缓存（缺省值：本仓主链路多为带签名请求，
  /// 缓存必须显式 opt-in）。
  onlyNetwork,

  /// 只读缓存，未命中报错（离线模式）。
  onlyCache,

  /// 命中且未过期直接短路返回，否则走网络。
  cacheFirst,

  /// 优先网络，失败降级读缓存（过期条目也兜底返回）。
  networkFirst,

  /// 先把缓存塞入 `extra['staleResponse']` 供调用方首屏渲染，
  /// 同时继续网络刷新（SWR；dio 单请求模型无法双发射）。
  cacheThenNetwork,
}

/// 单条缓存。
class HttpCacheEntry {
  HttpCacheEntry({
    required this.data,
    required this.savedAt,
    required this.ttl,
    this.statusCode,
  });

  final dynamic data;
  final int? statusCode;
  final DateTime savedAt;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(savedAt) > ttl;

  /// 还原为 dio 响应（短路/降级返回用）。
  Response<dynamic> toResponse(RequestOptions options) => Response<dynamic>(
    requestOptions: options,
    data: data,
    statusCode: statusCode ?? 200,
  );
}

/// 缓存存储端口（磁盘实现由宿主注入）。
abstract class HttpCacheStore {
  Future<HttpCacheEntry?> get(String key);

  Future<void> put(String key, HttpCacheEntry entry);

  Future<void> remove(String key);

  Future<void> clear();
}

/// 内置内存 LRU 存储（get 触发移尾，超容量淘汰最久未使用）。
class MemoryLruCacheStore implements HttpCacheStore {
  MemoryLruCacheStore({this.capacity = 200})
    : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final _entries = <String, HttpCacheEntry>{};

  int get length => _entries.length;

  @override
  Future<HttpCacheEntry?> get(String key) async {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry; // 重插 = 移到迭代序末尾（最近使用）。
    return entry;
  }

  @override
  Future<void> put(String key, HttpCacheEntry entry) async {
    _entries.remove(key);
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first); // 淘汰最久未使用。
    }
    _entries[key] = entry;
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
