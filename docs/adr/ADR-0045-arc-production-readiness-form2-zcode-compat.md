# ADR-0045: 生产化总纲——形态②（自建后端）与 ZCode 兼容前端参数，P0 分批授权

- 分类: ARC
- 优先级: P1
- 状态: ACCEPTED（2026-10-02，用户拍板："全部推进；服务端采用和 ZCode 一样的自建后端服务，前端相关参数先全部保留和 ZCode 相同的"；配套盘点 `docs/production-readiness-gap-2026-10-02.md`）

## 背景

生产化盘点（§0 定位题）的三种商用形态中，用户选定**形态②：账号 + 消费订阅**——客户端免费、
计费在消费侧（Coding Plan 模式），后端自建。决策的直接后果：**前端参数层现在就要与 ZCode 的
线上客户端逐字对齐**（端点路径、请求头、协议字段名、provider 身份），使未来自建后端可以按
ZCode 已验证的契约实现，客户端不用二次迁移。

## 决策

### 1. ZCode 兼容参数层（`lib/model/zcode_compat/`，纯 Dart）

逐字保留以下参数（证据：归档当日 head 的 grep，见下）：

| 参数 | ZCode 事实 | 落点 |
| --- | --- | --- |
| API 基座 | `{origin}/api/v1`、`/api/v1/zcode-plan`、`/api/v1/zcode-plan/anthropic`、`/api/v1/zcode-plan/billing/current`、`/api/v1/zcode-plan/billing/balance` | `zcodeEndpoint.ts:262-270` → `zcode_endpoints.dart` |
| 请求头 | `X-Platform: {platform}-{arch}`、`X-Release-Channel`、`X-Device-Mid`；channel 映射 `stable→"1"`、`preview→"3"` | `zcode-source-headers.ts:51-57`、`manifestUpdateProvider.ts:37-41` |
| 更新/强更 | `/api/v1/releases/electron/manifest?platform&device_mid&channel`、`/api/v1/client/configs?app_version&platform`（forceUpdate.minimalVersion，离线 fail-open） | `manifestUpdateProvider.ts:40-93`、`forceUpdateGuard.ts:150-182` |
| OAuth | provider id `zai`（chat.z.ai）/`bigmodel`（bigmodel.cn）；`UserInfo{id,username,displayName,avatarUrl?}`；存储键 `oauth:active_provider`、`oauth:{provider}:access_token/refresh_token/user_info` | `oauth.ts:8-12,82-91,153-203` |
| 额度协议 | `UsageQuotaSnapshot{level,limits[]}` / `UsageQuotaLimit{type,bucketId?,periodStart/End?,meter?,usage?,remaining?,percentage?,nextResetTime?,usageDetails[]}`（字段名逐个保留，含可空位）/ `UsageQuotaUsageDetail{modelCode,displayName?,usage}` / 合成类型 `MCP_USAGE_LIMIT` | `usage-quota.ts:9-49` |
| 设备身份 | `deviceMid` UUID 持久化，计费/遥测头共用 | `deviceMid.ts:21-28` → `<support>/device_state.json` |
| 消费记账 | 本地 usage 表 30 天硬修剪（`usage.ts:17-18`）；指标=input/output/reasoning/cacheRead/cacheCreation tokens、TTFT、错误率 | `usage-stats.ts:170-251` 的本地子集 |

**不搬**：ARMS 遥测全家、插件商店、手机远控、CUA（沿用盘点 §5）；ZCode 的 localStorage 键名
（我们走自己的 store 文件，只保留 oauth 语义键在安全存储里的命名）。

**刻意偏离一处（登记）**：密钥存储不用 ZCode 的 AES-GCM `credentials.json`（那是 Electron
无 keychain 时的自研方案），Flutter 侧直接用 OS keychain（`flutter_secure_storage`）——
macOS Keychain / Windows DPAPI / Linux libsecret。参数兼容指的是协议层，不是存储机制。

### 2. P0 分批授权（每批三门禁 + 一次提交）

| 批 | 内容 | 落点 |
| --- | --- | --- |
| PA | zcode_compat 模型层 + 测试（纯 Dart，零依赖） | `lib/model/zcode_compat/` |
| PB | **密钥安全存储**（DEP：flutter_secure_storage）+ `settings.json` 损坏隔离（quarantine `.corrupt-<ts>`）+ `AppSettings` 版本化迁移表 + 明文 apiKey 一次性迁移 + 设置/偏好**重置入口** | `lib/state/` + 设置 Backup 节 |
| PC | **崩溃本地归档**（`<support>/logs/crash/`，5 文件/100MB，Flutter + Platform 双通道）+ **使用台账**（JSONL 月文件 + 30 天修剪 + 设置页"使用统计"节，runtime seam 接 genkit usage）+ 快捷键**注册表**（一处定义三方共用：托盘/热键/设置只读表，录制 UI 下一批）+ "打开日志"入口 | `lib/state/` + `lib/ui/settings/` |
| PD | 版本事实：`version: 0.1.0`、README/CHANGELOG 正式化、本 ADR 与登记表回填 | 根 |

### PE（2026-10-02 追加授权）：认证 UI——登录页与注册入口

**PE 已落**：照 ZCode 的登录经验实现（研究记录：WelcomeScreen 为全屏 gate，
provider 按钮 + API key 表单 + 唯一 skip 路径；**OAuth 走服务端发起的轮询流**——
`POST /api/v1/oauth/cli/init`（Bearer pollToken=客户端随机）→ 打开 authorize URL →
轮询 `GET /api/v1/oauth/cli/poll/{flowId}` 至 pending/failed/ready，ready 载荷=
`user + provider tokens + 共享 zcode JWT`，两 provider 令牌拼写各异都收；**无 PKCE、
无应用内注册表单**——注册发生在 provider/后端网页）：

- `lib/model/zcode_compat/auth_flow.dart`：init/poll DTO + `ZcodeAuthEndpoints`
  （init/poll 路径、`{origin}/register` 注册页 URL、5 分钟流超时）。
- `lib/state/auth_session.dart`：`AuthSession`——restore（缓存 profile + JWT 本地
  exp 校验，过期=重新认证）、`startBrowserFlow`（init→打开浏览器→轮询，网络/5xx
  容错、5 分钟硬超时、互斥身份域清理）、`logout`（active provider 全键清除 + 门重开）。
- `lib/ui/auth/welcome_screen.dart`：登录页（provider 按钮 Global/CN 标签、等待态、
  错误态重试、API key 表单 + skip、**「注册账号」链接打开自建后端 `/register` 网页**
  ——这是对 ZCode 面的唯一扩展：他们的注册在 chat.z.ai/bigmodel.cn 网页上，
  自建后端按同形提供）。
- `main.dart` 门禁接线：无 API key 且未登录 → 首启 gate；restore 先于首帧 gate 判定；
  手动登出重开门。
- 依赖：`http`（genkit 传递依赖升格直接依赖）。

### PF（2026-10-03 追加授权）：多 provider 列表化 + 头像菜单 auth rows

**PF 已落**：`ModelSettings` 获得稳定 `id`；`AppSettings` 获得 `savedProviders`
（已配置连接的地址簿，每条 id + 密钥在 keychain 自己的槽位）与 `activeProviderId`，
**schemaVersion 3**——迁移从已配置的活动连接播种书（p1），新文档透传。
SettingsStore 编排每条目的 keychain 槽位（保存 diff 条目、激活换槽、删除清槽；
同一条目更新就位、不同连接铸新 id——第二个 provider 静默覆盖第一个的等价缺陷由
它自己的测试抓出）；`toJsonWithoutSecrets` 剥离书内密钥、open 从槽位恢复——
盘上文档任何位置都不含钥。Models 节新增书 UI：保存已测连接、条目列表（凭据点）、
激活、删除。`AppSettings.==` 纳入书比较——静默吞掉保存的陈旧等价早退由同批测试抓出。
头像菜单 auth rows：`AuthSnapshot` 桥接会话通知；快捷菜单显示 Sign in（manualLogin
理由重开门，gate 现在尊重已有 API key 的手动登录）或 Sign out；`userProfile` 投影
登录身份（ZcodeUserInfo 增加 poll 载荷的 email）。

### PG（2026-10-03 追加授权）：mock 登录身份、帮助组、模型列表与暂缓项落库

**PG 已落**：① 用户指令"登录先 mock 写死在代码里"——`MockProfileRepository` 返回
固定游客身份（旅行者6324 / 游客订阅），签名投影照常；② 快捷菜单新增帮助组
（产品文档/用户社群/问题上报/给产品提需求/发现新版本/关于——ZCode 头像菜单同五项，
链接常量 `AppMeta` 占位域名待产品定夺；关于对话框显示版本，`AppMeta.version` 与
pubspec 由测试互钉）；③ Models 节增「模型列表」手动增删（`ModelSettings.manualModels`
持久化，`ModelDirectory` 合并手动 id，ZCode 模型列表同形的最小实现）；
④ **暂缓项落库**：`docs/backend-contract-2026-10-03.md`（自建后端五组端点契约）+
`docs/signing-distribution-2026-10-03.md`（签名/公证操作手册 + 会员/订阅设计稿）。

### PH（2026-10-03 追加授权）：通知开关 + 注意力唤起

**PH 已落**：`AppSettings.notificationsOn`（默认开，仅关档落盘）+ General 节开关行 +
`lib/state/attention_service.dart`——busy→idle 边沿时若窗口隐藏（托盘路径）则
show+focus。真实消费者使其脱离 ADR-0022 的只写字段名单；窗口句柄经
`appWindow` provider 可空注入（测试无 binding 时不碰全局单例）。

### 3. 下一批（不在本 ADR 内实现，登记形状）

多 provider 列表化（`AppSettings.model` 单对象 → 列表 + 迁移）、代理/CA 设置（须真接
HttpClient 才许出现，反 ADR-0022 死字段律）、通知开关、快捷键录制 UI、OAuth 客户端与
升级购买 UI（等自建后端端点联调）、自动更新全量（前置：签名公证，另立 CFG ADR）。

## 后果

- `lib/model/zcode_compat/` 全部纯 Dart + 手写 `toJson/fromJson`，字段名与 ZCode 逐字一致
  （含驼峰与可空位），由测试对着归档值钉住——后端可按 ZCode 契约实现。
- 新依赖 `flutter_secure_storage`（^9.x）：三桌面 OS keychain；测试经接口注入 fake，不碰插件。
- `settings.json` 的 `apiKey` 字段在 PB 迁移后**不再写入**（读取兼容旧文件一次）；
  备份里的明文风险随迁移消失。
- 形态②的服务端件（OAuth、计费、额度、强更配置）全部【后端自建】，本 ADR 只锁前端参数；
  联调前客户端一律以本地/空态降级呈现（无账号也能用 BYOK——ZCode 同款立场）。
