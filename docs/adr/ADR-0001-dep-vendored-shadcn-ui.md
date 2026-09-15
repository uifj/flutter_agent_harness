# ADR-0001: vendored `packages/flutter-shadcn-ui` 不进版本库

- **状态**: RESOLVED
- **分类**: DEP
- **优先级**: P2
- **影响维度**: 上下文膨胀（浪费 Token）· 认知障碍（难以理解）
- **日期**: 2026-09-15
- **来源**: AI 代理配置审计（重写 `.qoder/rules` 时核查依赖真实性）+ 用户决策
- **修复 commit**: d72ff4c（`.gitignore` 增加 `/packages/flutter-shadcn-ui/`）

## 背景（Context）

仓库里存在一份第三方 UI 库的完整拷贝 `packages/flutter-shadcn-ui/`，但**它不属于本项目的构建输入**，证据如下：

1. 不是依赖：`pubspec.yaml` 的 `dependencies` / `dev_dependencies` 中无 `shadcn_ui`，也没有 `dependency_overrides` 或 path 引用（`grep -n "shadcn" pubspec.yaml` 无输出）。
2. 未被使用：`grep -rn "package:shadcn" lib/ test/` **零命中**；本项目 UI 走自研 `lib/ui/primitives/`（13 个自绘件）+ `flutter_lucide` 图标 + `lib/theme/dsw_*` 令牌。
3. 体积与来源：5.7 MB / 693 个文件，含上游自带的 `.github/`、`.gitignore`、`example/`、`playground/`、`fonts/`、`scripts/`、`test/`。副本内**没有** `.git` 目录，因此无法靠 submodule 或 `git log` 追溯它对应上游哪个 commit。
4. 版本可考：`packages/flutter-shadcn-ui/pubspec.yaml` 声明 `name: shadcn_ui` / `version: 0.56.3` / `repository: https://github.com/nank1ro/flutter-shadcn-ui`。
5. 它已经在被"只读地"使用：`repomix.config.json` 把它的 `lib/**`、`docs/**`、`example/**`、`playground/**`、`test/**` 等全部排除，只保留 README/pubspec 与 `skills/shadcn-ui-flutter` 组件文档当 API 参考；`.qoder/skills/shadcn-ui-flutter` 即同一套文档的副本。

风险：如果整份入库，5.7 MB 非自有代码会永久占据 Git 历史，且后续每次 vendored 更新都要重演一次；如果不记录来源，下一个人会不知道该目录能不能删、从哪来、对应哪个版本。

## 决策（Decision）

**保持该目录在工作区但被 Git 忽略**，并把"它是谁、来自哪、什么版本、拿来干什么"落在本 ADR 里。`.gitignore` 增加 `/packages/flutter-shadcn-ui/`。

候选方案与取舍：

| 方案 | 取舍 |
| --- | --- |
| A. 整份入库（693 文件） | 得到"clone 即有完整源码"，代价是历史里永久含 5.7 MB 上游代码及其 `.github`/`example` 噪声。否决：没有任何构建步骤需要它 |
| B. 只提交其文档部分（`skills/` + README + pubspec） | 体积可控，但要维护一份"挑出来的子集"，且 Git 里出现一个不能直接用的半截包，认知负担反而更高。否决 |
| C. 改成 git submodule 指向上游 | 需要网络与额外检出步骤，而本项目既不编译也不修改它。否决（YAGNI） |
| **D. gitignore + 本 ADR 记录 pinned 版本** | 最小且可复现：需要完整源码时按 `git clone https://github.com/nank1ro/flutter-shadcn-ui` 取 `v0.56.3`；需要查组件 API 时读已入库的 `.qoder/skills/shadcn-ui-flutter/`。**选定** |

配套约束：`.qoder/skills/shadcn-ui-flutter/` **要入库**（它是本项目 UI 决策的参考文档，且是 D 方案能省掉 B 的前提）；该 skill 的使用守卫见 `.qoder/rules/workflow.md` §2。

## 后果（Consequences）

- **正面**: 仓库历史只含自有代码；新 clone 的人从本 ADR 就知道该目录是刻意的本地参考、去哪重新获取、对应哪个上游版本。
- **负面/风险**: 换机器后该目录不会自动出现，读 `packages/flutter-shadcn-ui/lib/` 的习惯会失败；离线场景需先自行 clone。副本与上游之间没有自动同步机制，`0.56.3` 会随时间过期。
- **中性**: `repomix.config.json` 里针对该目录的排除规则变得只对"本机恰好有这份拷贝"的人生效——打包时若目录不存在，那些 pattern 空转，不报错。

## 验证（Verification）

```
git ls-files packages | wc -l            # 期望 0
git check-ignore -v packages/flutter-shadcn-ui/pubspec.yaml   # 期望命中 /packages/flutter-shadcn-ui/
git status --porcelain                   # 期望不再出现 packages/
flutter analyze                          # 期望不受影响（它本就不是依赖）
```

## 关联（Links）

- 代码: `pubspec.yaml`（无 `shadcn_ui`）、`repomix.config.json`（`ignore.customPatterns` 中 8 条针对该目录）
- 规则: `.qoder/rules/workflow.md` §2（`shadcn-ui-flutter` 的守卫）、`AGENTS.md` §6
- 参考文档入库位置: `.qoder/skills/shadcn-ui-flutter/`（39 文件，两份镜像一致）
- 上游: https://github.com/nank1ro/flutter-shadcn-ui ，pinned `0.56.3`
- 关联 ADR: —
