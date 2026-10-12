import 'dart:async';
import 'config_service_impl.dart';

typedef OnConfigChangedListener = void Function(String key, String value);
typedef DMChangedListener = void Function(
    String key, String value, bool isStrongControl);

abstract class Config {
  static Config? _instance;

  static Future<void> initialize({Config? instance}) async {
    if (_instance != null) return;
    _instance = instance ?? await ConfigServiceImpl.create();
  }

  static Config getInstance() {
    final inst = _instance;
    if (inst == null) {
      throw StateError('Config not initialized');
    }
    return inst;
  }

  Future<Map<String, String>> getAllProperties();
  Future<String?> getConfig(String key);
  Future<bool> setConfig(String key, String value);
  Future<bool> deleteConfig(String key);
  Future<String?> getSecure(String key);
  Future<String> getUmid();
  Future<bool> setSecure(String key, String? value);
  Future<bool> deleteSecure(String key);
  Future<String?> getConst(String key);
  Future<bool> isStrongControl(String key);
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<Map<String, dynamic>?> getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);
  Future<bool> clearAllConfig();
  Future<bool> clearAllSecure();
  void registerOnConfigChangedListener(
      String configKey, OnConfigChangedListener? listener);
  void registerDMChangedListener(String configKey, DMChangedListener? listener);
  void close();
}
