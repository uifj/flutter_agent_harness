# 技术债与缺陷登记表（debt-register）

本文件是本仓库**唯一的状态源**：所有已登记问题的分类、优先级与当前状态在此总览，细节与证据在下钻的 ADR 里。修改规则、分类、状态机见 [README.md](README.md)。

## 已登记

| 编号 | 标题 | 分类 | 优先级 | 状态 | 日期 | ADR |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-0001 | vendored `packages/flutter-shadcn-ui` 不进版本库 | DEP | P2 | RESOLVED @ d72ff4c | 2026-09-15 | [链接](adr/ADR-0001-dep-vendored-shadcn-ui.md) |

## 待立 ADR 的观察

以下是已经确认存在、但尚未走完"提案 → 批准"流程的问题。**修任何一个之前先补 ADR 并置 ACCEPTED**（纪律见 [README.md](README.md)）。

| 现象 | 证据 | 建议分类 | 建议优先级 |
| --- | --- | --- | --- |
| i18n 双语对齐无守卫 | `lib/l10n/locales.dart:11-13` 注释声称 en 会"在 test 时对照校验"，但 `grep -rn "enStrings\|zhStrings" test/` 零命中；当前键集恰好对齐（en/zh 各 251），纯靠手动维持 | TST | P2 |
| `README.md` 仍是 Flutter 包模板 | 文件通篇 `TODO:`，无一句项目说明；新人和代理拿它当入口会拿到零信息 | DEBT | P2 |
| macOS 分发缺口 | `CODE_SIGN_IDENTITY = "-"`、无 `DEVELOPMENT_TEAM`、未配 hardened runtime / `notarytool` 公证 → 产物只能本机运行；且 `.gitignore` 缺 `*.p12`/`*.cer`/`*.mobileprovision`，一旦有人放证书就会入库 | CFG | P1（若要对外发布） |
| 无 CI / 无版本推进 | 仓库无工作流文件，`pubspec.yaml` 仍 `version: 0.0.1`；analyze/format/test 全绿只靠人自觉 | DEBT | P2 |
| 只有 macOS 目标 | 仅 `macos/` 目录；`xterm` / `flutter_pty` / `flutter_inappwebview` / `pasteboard` 的桌面实现是否覆盖 Windows/Linux 未验证 | ARC | P2（若非目标则 DEFERRED） |

## 已闭环

| 编号 | 标题 | 分类 | 闭环方式 | 日期 |
| --- | --- | --- | --- | --- |
| — | AI 代理配置（`.qoder`/`.trae`/`AGENTS.md`）内容全属另一项目 | CFG | 按本仓库事实重写三份规则与入口文档，并裁掉 7 个与现状冲突的 skill | 2026-09-15 |

> 该条不占 ADR 编号：它是配置层的一次性纠正，无代码改动、无遗留状态。若日后再次发现代理配置漂移，按 README 流程立 ADR。
