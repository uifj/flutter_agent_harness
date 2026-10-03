# ADR-0049: 启动不许由 keychain 答不答应决定

- **状态**: ACCEPTED
- **分类**: DEF（启动路径缺陷）
- **优先级**: P1
- **影响维度**: 生产功能 / 安全合规
- **日期**: 2026-10-03
- **来源**: 用户要求本地运行；一次 `flutter run -d macos` 直接崩在启动第 102 行
- **修复 commit**: 7ab258f

## 背景（Context）

`flutter run -d macos` 在这台机器上**起不来**，日志是一份未处理异常：

```
Unhandled Exception: PlatformException(Unexpected security result code,
  Code: -34018, Message: A required entitlement isn't present., -34018, null)
#2  FlutterSecureStorage.write   (flutter_secure_storage.dart:114)
#3  SettingsStore.open           (lib/state/settings_store.dart:56)
#4  main                         (lib/main.dart:102)
```

两条独立原因叠在一起：

1. **插件默认走的是 data-protection keychain**。`MacOsOptions` 的 `useDataProtectionKeyChain` 默认 `true`（`flutter_secure_storage-9.2.4/lib/options/macos_options.dart:10`），而这条 API 的访问组是从**代码签名身份**推出来的；本项目的现状是 ad-hoc 签名、没有 `DEVELOPMENT_TEAM`（`.qoder/rules/build.md` §4 记着这条缺口）。于是每一次 read/write 都回 `-34018`。
2. **一次拒绝被当成可以忽略，于是它同时是致命的和毁数据的**。`settings_store.dart`（修复前 55-64）先 `await secrets.write(...)`，**紧接着无条件**把清理过的文档 tmp+rename 落盘。写失败会抛出、启动死亡——这是致命；而一旦有人只把 `await` 用 try 包住而不看结果，磁盘上的明文密钥会被删掉、keychain 里却没有——那是把用户唯一的副本抹了。同一段之后（修复前 72-91）的读回完全在 `try` 之外，`read` 抛同样死。

对照文件自己写的规则（`settings_store.dart:35-39`）："丢一个存下来的 base URL 是可恢复的，起不来不是"。这条规则当时只落在了 `FileSystemException` / `FormatException` 上，没落在外部服务上。

## 决策（Decision）

1. **接缝处一次说清用哪把 keychain**：`SecureSecretStore` 显式 `MacOsOptions(useDataProtectionKeyChain: false)`，走经典的文件 keychain。它不需要签名身份，仍然满足 ADR-0045 的那句话——密钥不落 `settings.json`。写在这一处而不是散到十几个调用点，是因为"这台机器够不够得到 keychain"是一个事实，不是一个每处要重问的问题。
2. **拒绝必须被知道，而不是被吞掉**：`SettingsStore.open` 用 `_keychainAllows(call)` 拿到"这次到底成没成"。没成，就把明文留在文档里并**跳过**清理重写；成了，才按原来的方式盖章落盘。读回同理：够不到 keychain 时，文档自己带的字段继续生效，异常就地了结。
3. **不做的事**：不加"keychain 不可用就退回明文"的全局开关，也不在 UI 上加提示条。前者会把一个安全决定变成运行时随机行为；后者此刻没有可说的新事实——设置页那枚凭据点本来就在回答"这台设备存下密钥了吗"。

## 后果（Consequences）

- **正面**: 本机 debug 起得来，且密钥真的搬进了 keychain——证据：启动后 `settings.json` 变成 `schemaVersion: 3` 且 `model.apiKey` 为空串，`security dump-keychain` 里出现 1 枚 `settings:model:api_key`；`AuthSession` 启动时那四次读也不再能杀死进程。
- **负面/风险**: 经典 keychain 的 ACL 认的是二进制路径，构建产物被移动或改名后可能再弹一次授权；它是两把 API 里较弱的一把。**签名（Developer ID + hardened runtime）落地后要回到这一行重估**，届时迁移需要同时读两把（否则旧条目读不到）。
- **中性**: `_keychainAllows` 是本文件第二枚"外部服务可以说不了"的闸门（第一枚是 `_quarantine`），后续任何新增的 keychain 调用点都该问它，而不是自己 try 一下当没事发生。

## 验证（Verification）

- 实跑：`flutter run -d macos` → 进程存活，日志 0 条未处理异常（只剩 macOS 输入法那条无害的 `IMKCFRunLoopWakeUpReliable`）。
- 守卫 `test/settings_hardening_test.dart` 新增三棵，各自单独反向验过：把 `_keychainAllows` 改成直接 `await call()` → 两棵拒绝守卫同时红；只删读回那段 `try` → 第二棵红；把 `useDataProtectionKeyChain: false` 拿掉 → 源码那棵红。恢复后 19 棵全绿。
- 门禁：`dart format` 0 changed、`dart analyze --fatal-infos lib test tool spike` 干净、`flutter test` `+1324 -2`（两条已登记失败，零新增）、`dart tool/check_architecture.dart` 7 recorded / 0 new。

## 关联（Links）

- ADR-0045 PB/PF（密钥进 keychain、设置隔离与迁移——本 ADR 是它没考虑"外部服务会说不"的那一半）
- `.qoder/rules/build.md` §4（ad-hoc 签名与公证缺口）、§3（entitlements 是产品能力边界）
- `docs/production-readiness-gap-2026-10-02.md`（P0 第 3 项：API key 明文）
