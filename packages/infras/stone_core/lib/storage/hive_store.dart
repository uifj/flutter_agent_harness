/// Hive-backed list store for infrastructure consumers.
///
/// Wraps [Hive] initialization (anchored at the platform documents directory
/// via `path_provider`) and a named box's list read/write, so feature packages
/// can persist list values without depending on `hive_ce` or `path_provider`
/// directly.
library hive_store;

import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

/// Static gateway over a [Hive] box storing `key -> List<Map>` entries.
class HiveStore {
  HiveStore._();

  /// Initializes Hive at the application documents directory and opens [boxName].
  static Future<void> init(String boxName) async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox(boxName);
  }

  /// Stores [value] under [key] in [boxName].
  static Future<void> put(
    String boxName,
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await Hive.box(boxName).put(key, value);
  }

  /// Reads the list stored under [key] in [boxName], or null when absent.
  static List<dynamic>? get(String boxName, String key) {
    final data = Hive.box(boxName).get(key);
    return data is List ? data : null;
  }
}
