/// network_core — Stow 企业级网络基础设施层
///
/// 从 stone God Package 提取的完整 HTTP 栈（去 stone 化 Phase 2）。
/// 包含：
/// - [HttpManager] — Dio 单例 + 拦截器链
/// - [ApiClient] — 高层 REST API 封装
/// - [MultipartUploader] — 通用分片上传引擎（预签名 URL 回调注入）
/// - [FormPostUploader] — OSS PostObject 表单直传（policy 预签名）
/// - [ResponseEnvelope] — 多后端响应格式兼容（Passthrough/RestCode/Wyota）
/// - [NetworkCacheInterceptor] — 请求级 opt-in HTTP 缓存（五策略 + LRU）
/// - [OfflineSyncService] — 离线同步服务
/// - 拦截器：RefreshLogin / Retry
/// - 网络抽象接口与实体
library;

export 'network/api_client.dart';
export 'network/cache/http_cache.dart';
export 'network/cache/network_cache_interceptor.dart';
export 'network/env_entity.dart';
export 'network/http_manager.dart';
export 'network/http_utils.dart';
export 'network/interceptors/refresh_login_interceptor.dart';
export 'network/interceptors/retry_interceptor.dart';
export 'network/multipart/form_post_uploader.dart';
export 'network/multipart/multipart_upload_models.dart';
export 'network/multipart/multipart_uploader.dart';
export 'network/network_abstractions.dart';
export 'network/offline_sync_service.dart';
export 'network/refresh_login_model.dart';
export 'network/response_envelope.dart';
export 'network/result.dart';
