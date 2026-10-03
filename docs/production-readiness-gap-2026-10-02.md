# agent_harness 生产化/商用差距盘点

- **日期**: 2026-10-02（基线：develop `3782f2c`，企划编辑器 P10-d 落地后）
- **问题**: 要支持商用（生产级），还需要补哪些功能与能力——设置中心、用户中心、分发、账户、商业化、运营。
- **证据来源（三路，全部带 path:line，行号只对当日归档/HEAD 有效）**:
  1. **ZCode-main 设置中心**（16 节的产物形态与基础设施：`packages/ui/src/settings/settingsPageConfig.ts:57-159`、`packages/services/src/setting/settingService.ts`）；
  2. **ZCode-main 商用运营面**（OAuth/身份 `packages/services/src/oauth/oauthService.ts`、Coding Plan 计费 `packages/shared/src/coding-plan-subscription.ts:5-519`、自动更新 `packages/desktop/src/main/autoUpdater.ts` + `forceUpdateGuard.ts`、ARMS 遥测 `appARMSBootstrap.ts`、加密凭据 `credentialService.ts:18-33`）；
  3. **Anytype 清单**（`docs/anytype-feature-inventory-2026-10-01.md` §12 设置/§13 账户/§14 会员，`MembershipConstants.kt:5-12`、`ProfileScreen.kt`、`AppearanceScreen.kt`）；
  4. **本项目现状**（现场清点：8 节设置、mock profile、备份、托盘/热键、会话墓碑）。
- **约束**: 本文档只做盘点，不含代码改动；任何动作先按 `docs/README.md` 立 ADR。红线沿用
  `docs/zcode-vs-agent-harness-2026-09.md` §8（不 fork ZCode 代码只取设计思想 + Apache-2.0 归属、
  依赖要 DEP ADR、i18n 双语守卫、三平台口径）与 AGENTS.md §7。

---

## 0. 一页结论：先回答定位题，再谈功能

**"商用"有三种形态，功能清单完全不同，必须先拍板（这是 P0 之前唯一的决策）：**

| 形态 | 需要什么 | 对应 ZCode 的哪部分 |
| --- | --- | --- |
| **① 单机 BYOK 卖断**（用户自带 API key，一次性买断/订阅 app 本身） | 签名分发 + 安全存储 + 更新通道 + 好的设置中心。**不需要**账号/服务端 | 只需其设置中心与自动更新，OAuth/计费/遥测全不搬 |
| **② 账号 + 消费订阅**（Coding Plan 模式：客户端免费，卖模型额度） | ①的全部 + OAuth + 计费客户端 + 额度展示 + 设备身份。**需要服务端**（ZCode 的 relay/配对/支付服务端不在其仓库里，本项目也没有） | 全量，但服务端要自建 |
| **③ 企业内网/团队** | ①或② + 团队/座位/组织上下文 | 其 `coding-plan-subscription.ts:359-519` 的企业档 |

**建议**：先按 **①** 补齐生产门槛（本章 P0），用户中心做成**本地增强**（把 ADR-0006 预留的 Supabase 缝
继续留着但不兑现——Mock 背后换成一个真实的本地 profile store，头像/昵称/订阅标签由用户自填或由许可文件决定）。
形态②的每一项都标了【需服务端】，立项前先立"要不要服务端"的 ADR——那是产品决策不是功能清单。

**当前最锋利的一个事实**：`settings.json` 里 **API key 是明文落盘**（`lib/state/settings_store.dart`，
无加密层）。ZCode 用 AES-256-GCM 加密的 `credentials.json` + 损坏隔离（`credentialService.ts:18-33,104-117`），
Anytype 的助记词有 Keychain 屏。单机商用第一件事就是把密钥存储收口。

---

## 1. P0 商用门槛（不解决就不能对外发）

| # | 缺口 | 现状（本项目） | 上游参照 | 动作与 ADR |
| --- | --- | --- | --- | --- |
| P0-1 | **签名/公证/分发** | ad-hoc 签名，无 DEVELOPMENT_TEAM、无 notarytool，CI 无 codesign；`.gitignore` 缺证书规则（登记表 `:87-88`） | ZCode production/preview 双 flavor（`shared/src/env.ts:25-39`）；Anytype 出包走官方渠道 | **一切的前置**。CFG ADR：证书与 secrets 管理、hardened runtime、三平台公证流水线 |
| P0-2 | **版本与发布事实** | `version: 0.0.1`，README/CHANGELOG 是 Flutter 模板（登记表 `:86,88`） | Anytype About 屏 7 字段技术信息（`AboutAppScreen.kt:90`：version/build/library/account/device id…） | CFG：版本策略 + README/CHANGELOG 正式化 + About 数据从 packageInfo 取 |
| P0-3 | **API key 加密存储** | 明文 `settings.json` | ZCode AES-256-GCM `credentials.json`、原子写、损坏隔离永不覆盖（`credentialService.ts:18-33,104-117`） | SEC + DEP ADR：`flutter_secure_storage`（OS keychain）或同等加密文件；迁移旧明文 |
| P0-4 | **设置文件损坏隔离** | 三个 store corrupt 一律读默认（数据静默丢失） | ZCode 损坏文件隔离为 `setting.json.corrupt-<ts>` + 重试 ×3 + 写队列（`settingService.ts:67-94,246-273`） | DEF：损坏隔离 + 备份一份再重置；沿用我们已有的原子 tmp+rename |
| P0-5 | **崩溃与错误留痕** | 无任何捕获；错误只进控制台/吐司 | ZCode 本地崩溃归档 `~/.zcode/v2/crash/`、5 文件/100MB、上报 URL 指向 `.invalid`（`desktopCrashCapture.ts:20,23-24`）——**他们也没上云** | DEF：Flutter/Material 捕获 + 本地崩溃目录 + "导出日志"入口（Anytype Debug 屏有现成形态，`DebugScreen.kt:73-170`）。零新依赖可做 |
| P0-6 | **许可与第三方声明** | 无 LICENSE 文件内容决策、无 THIRD-NOTICES 汇总（shadcn/board_panel/genkit 全家） | ZCode NOTICE.md §2-§4 的出站数据表 + 归属条目 | CFG：选 LICENSE、写 NOTICE（若按红线 9 取用过任何 ZCode 设计之外的素材则必须） |
| P0-7 | **卸载/重置语义** | 无"清除全部数据"入口 | ZCode browser 节的 clear data with confirm；Anytype logout/删号双确认（`graph.xml:399-403`） | DEF：设置里加"重置应用数据"（备份提示 + 双确认） |

## 2. 设置中心补全（P1：对照 ZCode 13 节逐节盘点）

现状：8 节（general/appearance/models/workspace/workbench/extensions/approvals/backup，
`lib/ui/settings/model_settings.dart:62-71`），双入口一致性有守卫（ADR-0006）。
下表只列**缺的**；"已有"= 与 ZCode 对齐的部分不重复。

| ZCode 节 | 我们缺什么 | 建议 | 成本 |
| --- | --- | --- | --- |
| general（语言/终端/代理/通知/任务归档/数据目录/重开引导） | **通知开关已落**（ADR-0045 PH：注意力唤起）；**HTTP 代理与 CA 证书**（国内商用刚需，ZCode `settingsPageHelpers.tsx:450-552`）仍缺；**任务自动归档档位**；**数据目录迁移**（`settingService.ts:339-358` 的整目录拷贝） | 代理/CA 等网络层真接；数据目录迁移挂 P2 | 中 |
| appearance（主题/字号/代码预览） | 主题三档与字号三档**已有**（ADR-0017 S3）；缺**代码预览独立主题/字号**（我们有 Source 模式用 re_editor，字体已是活设置） | 低优先 | 低 |
| shortcuts | **3 个热键硬编码**（`hotkey_service.dart:48-94`），无注册表/录制/冲突检测 | ZCode 注册表 24 命令 + 录制 + 物理等价冲突判定 + **抢占**（`conflicts.ts:63-94,196-245`）值得整套搬设计；落点一处定义供托盘/设置/热键三方共用 | 中（纯本地） |
| model | 模型目录/测试连接/能力位**已有**（ADR-0010）；缺 **OAuth 型 provider**（见 §3）、缺**多 provider 并存**（当前单 provider 单 key——`AppSettings.model` 是一个对象） | 多 provider 列表化是商用 BYOK 的基本盘；ZCode 的 `ModelProviderSection.tsx`（1161 行）形态可参照 | 中-高 |
| usage | **本地使用统计已落**（ADR-0045 PC：JSONL 30 天修剪 + 设置面板）；缺 Coding Plan tab（等自建后端联调） | ZCode 双 tab：本地 App Usage（SQLite 聚合 tokens/TTFT/错误率，30 天硬修剪 `usage.ts:17-18`）+ 服务端 Coding Plan 额度 | 中 |
| migration | 无 | ZCode 两件：**Claude Code 会话导入**（`MigrationSection.tsx:28-227`）与**17 家外部 agent 的设置同步**（`settings-sync.ts:1-19`）。后者是获客利器（用户从竞品搬过来零成本）；前者看我们的会话格式是否值得做导入器 | 中-高 |
| memory/hooks/subagents/browser/automations/mcp | mcp 已有（stdio+http 两型）；**hooks 未做**（B5，安全面扩大，SEC ADR 前置）；子 agent profile 目录未做（B3）；automations 未做（B6） | 沿旧路线图 B3/B5/B6 顺序，不因商用改变优先级 | 高（各一档） |

**设置基础设施的差距**（比节数更重要）：ZCode 的 zod schema + 默认值表 + **字段级迁移函数**
（`migrateLegacyLocalePreference:227` 等）+ 损坏隔离 + 跨窗口广播。我们有原子写与
`settings_reach_test` 反死字段守卫，缺**默认值集中与版本化迁移**——P0-4 顺手建 `AppSettings`
迁移函数表（版本号 + 逐版迁移），否则以后每加字段都是一次静默丢配置的风险。

## 3. 用户中心与账户（P1/P2，形态②专用，多数【需服务端】）

现状（ADR-0006 遗产）：`user_profile.dart` 四字段 + `MockProfileRepository`（`profile_repository.dart:33-43`），
侧栏头像与快捷菜单在读它；Supabase 只是注释里的缝（`:10-19`），pubspec 无任何 auth 依赖。
**本地形态①要做的**：把 Mock 换成真实本地 profile（昵称/头像色/自填订阅标签，落 profile.json，
进备份清单）——一天工作量，UI 零改动。

**形态②的账单与身份面**（全部【需服务端】，ZCode 证据留作设计参照）：

| 能力 | ZCode 证据 | 备注 |
| --- | --- | --- |
| OAuth 登录（双 provider、深链回调 `zcode://`、JWT 本地 exp 校验、登出两档） | `oauthService.ts:53-484`、`desktopOAuthDeepLink.ts:13-53` | Flutter 侧要 deep link 接收 + 系统浏览器外开；三平台行为各异 |
| 设备身份 deviceMid（UUID，计费/遥测头） | `deviceMid.ts:21-28` | 本地生成即可，无需服务端也能先落 |
| 订阅协议类型全集（支付宝/微信/Stripe/PayPal、订单/退款/邀请码） | `coding-plan-subscription.ts:5-46` | 纯协议层可先抄形状 |
| 企业档（LITE/PRO/MAX、座位、组织上下文） | `:359-519` | 形态③ |
| 额度快照（bucketId/period/remaining/nextReset、MCP 配额） | `usage-quota.ts:9-49` | 服务端供数 |
| 升级购买 UI（内嵌 webview + 可信来源检查 + 登录态传递） | `CodingPlanUpgradeDialog.tsx` | — |
| 额度用尽的聊天内升级 CTA | `ChatErrorBanner.tsx:221-225` | **_advisory only_——ZCode 不做本地强制限额**，这个立场值得沿用 |

对照 Anytype：会员 8 档 + Stripe/加密/应用内三支付（§14，`BillingClientLifecycle.kt` 是其唯一支付实现）——
两家共同点：**客户端不做许可证服务器，计费在消费侧**。形态①的"卖断"若要防白嫖，许可证校验是唯一
要自建的服务端件（或用 Gumroad/LemonSqueezy 类现成 license API，DEP ADR）。

## 4. 分发与运营（P1）

- **自动更新**：前置 P0-1。ZCode 全流程（manifest+sha512、stable/preview 双通道、下载可取消、
  退出装包防半更、发布说明本地化、强制更新门 `forceUpdateGuard.ts:150-182`）都是**服务端 + electron-updater**
  的产物；Flutter 侧等价物是 `auto_updater`/`flutter_auto_updater` 或自写 sparkles 集成——DEP ADR。
  最小可用版：设置页"检查更新"按钮 + 打开 Release 页（`url_launcher` 已在依赖里，零新依赖）。
- **遥测**：ZCode 的 ARMS 全家（~20 采样器、redaction 门、0.1% 采样）**不搬**（厂商锁定 + 无服务端）。
  形态①的诚实版本：本地 usage 统计（§2 usage 行）+ 崩溃本地归档（P0-5）+ "导出诊断"按钮。
- **备份**：已有 zip+zip-slip 门（ADR-0042）；补两件：**API key 不进备份**（等 P0-3 加密后重新评估）与
  **定时自动备份**（Anytype 无此能力，ZCode 也无——低优先差异化）。

## 5. 明确不做的（与既有裁决一致）

- 插件商店/内置播种/featured 远控（旧 C3，无服务端）；
- 手机远控/relay（旧 C2）；
- ARMS 遥测全家（厂商锁定）；
- 计算机使用 CUA（上游也是占位）；
- **在做完 P0 之前不新增任何 P1 功能**——签名与密钥存储是门槛，门槛没过，功能越多暴露面越大。

## 6. 建议执行顺序

1. **定位拍板**（形态①/②/③）——用户决策，写进 ADR。
2. **P0 一周量级**：P0-3 密钥加密（SEC+DEP）→ P0-1 签名公证（CFG）→ P0-2 版本事实（CFG）→
   P0-4 损坏隔离+迁移表（DEF）→ P0-5 崩溃归档（DEF）→ P0-6 许可声明（CFG）→ P0-7 重置入口（DEF）。
3. **P1 按形态**：① = 多 provider 列表 + 本地 usage + 快捷键注册表 + 本地 profile 真实化 + 会话/设置导入；
   ② = 先立服务端 ADR 再谈 OAuth/计费。
4. **P2**：数据目录迁移、自动更新全量、企业档。
