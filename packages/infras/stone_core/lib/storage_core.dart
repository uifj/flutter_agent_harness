/// storage_core — Stow 企业级存储基础设施层
///
/// 对外暴露两套存储底座，供上层（appunits/pudding）复用，避免各包直接依赖
/// `shared_preferences` / `flutter_secure_storage` / `hive_ce` / `path_provider`：
/// - [Config] — SharedPreferences（普通 KV）+ FlutterSecureStorage（加密 KV）
///   的统一门面（get/set/delete、secure、json、umid、变更监听）。
/// - [HiveStore] — Hive 盒存储的静态网关（init + list 读写）。
library;

export 'storage/config.dart';
export 'storage/hive_store.dart';
