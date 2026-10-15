import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss;
import 'config.dart';

class ConfigServiceImpl implements Config {
  final SharedPreferences _prefs;
  final fss.FlutterSecureStorage? _secureFss;
  final Map<String, OnConfigChangedListener?> _configListeners = {};
  final Map<String, DMChangedListener?> _dmListeners = {};

  ConfigServiceImpl._(this._prefs, this._secureFss);

  static Future<ConfigServiceImpl> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ConfigServiceImpl._(prefs, const fss.FlutterSecureStorage());
  }

  @override
  Future<String?> getConfig(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<bool?> getBool(String key) async {
    final v = await getConfig(key);
    if (v == null) return null;
    return v.toLowerCase() == 'true';
  }

  @override
  Future<bool> setConfig(String key, String value) async {
    final ok = await _prefs.setString(key, value);
    if (ok) {
      final l = _configListeners[key];
      if (l != null) l(key, value);
    }
    return ok;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    return await setConfig(key, value.toString());
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final s = json.encode(value);
    await setSecure(key, s);
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final s = await getSecure(key);
    if (s == null || s.isEmpty) return null;
    try {
      final v = json.decode(s);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> deleteConfig(String key) async {
    return _prefs.remove(key);
  }

  @override
  Future<Map<String, String>> getAllProperties() async {
    final map = <String, String>{};
    for (final k in _prefs.getKeys()) {
      final v = _prefs.get(k);
      if (v is String) {
        map[k] = v;
      }
    }
    return map;
  }

  @override
  Future<String?> getSecure(String key) async {
    final s = _secureFss!;
    return await s.read(key: key);
  }

  @override
  Future<bool> setSecure(String key, String? value) async {
    final s = _secureFss!;
    if (value == null) {
      await s.delete(key: key);
      return true;
    }
    await s.write(key: key, value: value);
    return true;
  }

  @override
  Future<bool> deleteSecure(String key) async {
    final s = _secureFss!;
    await s.delete(key: key);
    return true;
  }

  /// 实现：清空所有普通配置（SharedPreferences）
  /// 会删除SharedPreferences中的所有key-value，并触发所有配置的变更监听
  @override
  Future<bool> clearAllConfig() async {
    try {
      // 1. 获取所有key并记录（用于触发监听）
      final allKeys = _prefs.getKeys().toList();

      // 2. 清空SharedPreferences
      await _prefs.clear();

      // 3. 触发所有配置的变更监听（通知配置已清空）
      for (final key in allKeys) {
        final listener = _configListeners[key];
        if (listener != null) {
          listener(key, ''); // 空字符串表示配置已被删除
        }
      }

      // 4. 清空监听器映射（可选，根据业务需求）
      _configListeners.clear();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 实现：清空所有安全存储配置（可选）
  /// 谨慎使用！会删除所有加密存储的敏感数据（如UMID、token等）
  @override
  Future<bool> clearAllSecure() async {
    try {
      await _secureFss!.deleteAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getUmid() async {
    const k = 'device_umid';
    final existing = await getSecure(k);
    if (existing != null && existing.isNotEmpty) return existing;
    final r = Random();
    final suffix = List.generate(
      8,
      (_) => String.fromCharCode(97 + r.nextInt(26)),
    ).join();
    final v = '${DateTime.now().millisecondsSinceEpoch}_$suffix';
    await setSecure(k, v);
    return v;
  }

  @override
  Future<String?> getConst(String key) async {
    return null;
  }

  @override
  Future<bool> isStrongControl(String key) async {
    return false;
  }

  @override
  void registerOnConfigChangedListener(
    String configKey,
    OnConfigChangedListener? listener,
  ) {
    _configListeners[configKey] = listener;
  }

  @override
  void registerDMChangedListener(
    String configKey,
    DMChangedListener? listener,
  ) {
    _dmListeners[configKey] = listener;
  }

  @override
  void close() {}
}
