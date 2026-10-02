# 自建后端接口契约（ADR-0045 形态② · 供服务端实现）

> 本文是自建后端的**实现契约**：客户端参数层（`lib/model/zcode_compat`）的测试逐字钉住了
> 以下形状，后端照此实现即可与客户端零联调对接。行号引用 ZCode 归档
> （`_archive_project/ZCode-main`，2026-10-02 shallow head）。
> 状态源：ADR-0045；客户端联调前所有端点以本地/空态降级呈现。

## 1. OAuth 登录流（轮询式，`oauthService.ts:594-788`）

| 步骤 | 方法与路径 | 请求 | 响应 |
| --- | --- | --- | --- |
| 发起 | `POST /api/v1/oauth/cli/init` | `Authorization: Bearer <pollToken>`（客户端随机 32 字节 hex）；body `{"provider":"zai"\|"bigmodel"}` | `{code:0, data:{flow_id, authorize_url, expires_at(s), poll_interval_sec(s)}}` |
| 轮询 | `GET /api/v1/oauth/cli/poll/{flowId}` | 同 Bearer 头 | pending：`{code:0, data:{status:"pending"}}`；失败：`status:"failed"`；完成：见下 |

`ready` 载荷（三件必须齐全）：`data:{status:"ready", user:{user_id,name,email,avatar},
zai|bigmodel:{access_token, refresh_token}, token:<共享 JWT>}`。服务端须把
authorize_url 的回调重写到自己的 web 转移页（客户端不注册深链 scheme）。
流生命周期 ≤ 5 分钟（客户端硬超时）；网络/5xx 客户端继续重试，4xx 终止。

## 2. 注册与账户

- **注册页**：`GET {origin}/register`（网页表单，服务端自有）——客户端从欢迎页
  「注册账号」行以系统浏览器打开（ZCode 同形：注册在 provider 网页，无应用内表单）。
- **账户信息**：登录后客户端只读 `ready` 载荷的 `user`；服务端如需资料编辑页，
  自行承载（客户端暂无入口）。

## 3. 订阅与额度（`coding-plan-subscription.ts`、`usage-quota.ts:9-49`）

| 用途 | 路径 | 形状 |
| --- | --- | --- |
| 计费现状 | `GET /api/v1/zcode-plan/billing/current`、`/billing/balance` | `UsageQuotaSnapshot{level, limits[]}`；`UsageQuotaLimit` 字段名逐字（type/bucketId/periodStart/End/meter/usage/remaining/percentage/nextResetTime/usageDetails[]） |
| 模型调用 | `POST /api/v1/zcode-plan`（OpenAI 兼容）、`/api/v1/zcode-plan/anthropic`（Anthropic 兼容） | 网关按订阅额度放行；**客户端不做本地强制限额**——额度用尽返回错误，聊天内出升级 CTA |
| 支付 | 服务端承载（支付宝/微信/Stripe/PayPal、订单/退款/邀请码，`:18-46`） | 客户端只做升级入口跳转 |

## 4. 更新与强更（`manifestUpdateProvider.ts`、`forceUpdateGuard.ts`）

| 用途 | 路径 | 说明 |
| --- | --- | --- |
| 更新清单 | `GET /api/v1/releases/electron/manifest?platform={darwin\|windows\|linux}-{arch}&device_mid=&channel={1\|3}` | 文件须带 sha512/sha2（客户端校验）；请求头 `X-Platform`/`X-Release-Channel`/`X-Device-Mid` |
| 强更配置 | `GET /api/v1/client/configs?app_version=&platform=` | `forceUpdate.minimalVersion`；离线/出错 = fail-open 跳过 |

## 5. 通用约定

- 每请求可带 `X-Device-Mid`（客户端生成的 UUID v4，持久化于
  `<support>/device_state.json`）——计费与反馈归因用。
- 遥测：**客户端当前不上报任何遥测**（ZCode 的 ARMS 全家未搬，盘点 §5）；
  服务端不应假设遥测存在。
- 所有响应沿用 `{code, msg, data}` 信封；`code != 0` 视为业务失败。
