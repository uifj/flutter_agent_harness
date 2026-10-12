import 'package:cookie_jar/cookie_jar.dart';
import 'package:stone_core/storage_core.dart';

import 'storage.dart';

/// Cookie store backed by a Hive box via [stone_core's HiveStore][HiveStore].
///
/// The raw Hive init/box access is delegated to [HiveStore], so this package
/// does not depend on `hive_ce` or `path_provider` directly.
class HiveStorage implements StorageInterface {
  static const String _boxName = 'better_auth_cookies';

  static Future<void> init() async {
    await HiveStore.init(_boxName);
  }

  @override
  Future<void> saveCookies(String url, List<Cookie> cookies) async {
    final list = cookies
        .map(
          (c) => {
            'name': c.name,
            'value': c.value,
            'expires': c.expires?.millisecondsSinceEpoch,
            'path': c.path,
            'domain': c.domain,
            'httpOnly': c.httpOnly,
            'secure': c.secure,
          },
        )
        .toList();
    await HiveStore.put(_boxName, url, list);
  }

  @override
  Future<List<Cookie>> loadCookies(String url) async {
    final data = HiveStore.get(_boxName, url);
    if (data == null) return [];

    return data.map<Cookie>((c) {
      final cookie = Cookie(c['name'], c['value']);
      cookie.expires = c['expires'] != null
          ? DateTime.fromMillisecondsSinceEpoch(c['expires'])
          : null;
      cookie.path = c['path'];
      cookie.domain = c['domain'];
      cookie.httpOnly = c['httpOnly'] ?? false;
      cookie.secure = c['secure'] ?? false;
      return cookie;
    }).toList();
  }
}
