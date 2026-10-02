# 签名、公证与会员/商用待办（ADR-0045 · 暂缓项落库）

> 本文承接生产化盘点（`docs/production-readiness-gap-2026-10-02.md`）的 P0/P1 余项：
> **代码侧无法自行闭环、需要外部凭证或产品决策**的三件事，在此落库为操作手册与设计稿。
> 每节标了"解锁条件"——条件满足后按 ADR 纪律实施。

## 1. 签名与公证（P0-1，一切对外分发的前置）

**解锁条件**：Apple Developer 账号（$99/年）+ Windows 代码签名证书（OV 或 EV）。

### macOS

1. `.gitignore` 先补 `*.p12` / `*.cer` / `*.mobileprovision`（登记表 :87 的缺口，动手第一步）。
2. Xcode 里设 `DEVELOPMENT_TEAM` + `CODE_SIGN_IDENTITY = "Apple Distribution"`，
   `macos/Runner/Release.entitlements` 的改动**先立 ADR**（AGENTS.md §7 红线：那是能力边界）。
3. 公证：`xcrun notarytool submit`（App Store Connect API key 走 CI secret）；
   CI 的 `build.yml` 增加签名 + 公证 job（现无任何 codesign 步骤，登记表 :88）。
4. hardened runtime 必开（公证前置）；`flutter_secure_storage` 的 Keychain 访问在
   hardened runtime 下默认可用，无需额外 entitlement。

### Windows

1. OV 证书（EV 需硬件令牌，CI 不便）：signtool 对 exe/dll 签名。
2. SmartScreen 信誉需要时间积累，发布说明里写明。

### 更新通道（前置 = 本节完成）

- ZCode 形：manifest + sha512 + stable/preview 双通道 + 强更门
  （契约见 `docs/backend-contract-2026-10-03.md` §4）。
- Flutter 侧落地选型待 ADR：`auto_updater`（Sparkle/Winsparklin 封装）或自写
  下载+替换（下载、校验 sha512、退出替换三步）。

## 2. 会员/订阅设计稿（形态②，`coding-plan-subscription.ts:5-519` 为参照）

**解锁条件**：自建后端上线（契约见 `docs/backend-contract-2026-10-03.md`）+ 支付渠道决策。

- **档位**：建议起步三档（Free / Pro / Team），按月/按年；对齐 ZCode 的
  CONTINUOUS/ONE_TIME 与 MONTHLY/QUARTERLY/YEARLY 组合（`:359-419`）。
- **计费立场**（两家共同）：客户端免费，计费在**消费侧**；额度用尽只在聊天内出
  升级 CTA（`ChatErrorBanner.tsx:221-225`），**客户端不做本地强制限额**。
- **客户端 UI 待办**（后端联调后）：
  - 设置页 Usage 节加「Coding Plan」tab：额度余量/百分比/下次重置
    （`UsageQuotaSnapshot` 已在客户端参数层就位）。
  - 升级入口：聊天错误横幅 CTA + 设置页订阅卡（内嵌 webview 或外开浏览器，
    ZCode 用内嵌 webview + 可信来源检查，`CodingPlanEmbeddedWebviewDialog.tsx`）。
  - 侧栏头像菜单的订阅徽章：`AuthSnapshot.user.subscription` 槽位已预留。
- **许可证备选**（若走卖断而非订阅）：LemonSqueezy/Gumroad 类 license API，
  客户端持 license key → 后端校验 → 解锁；另立 ADR。

## 3. 后端实施清单（指针）

见 `docs/backend-contract-2026-10-03.md`——OAuth init/poll、`/register`、
计费/额度、模型网关、更新清单/强更五组端点，全部有 ZCode 归档行号背书。
