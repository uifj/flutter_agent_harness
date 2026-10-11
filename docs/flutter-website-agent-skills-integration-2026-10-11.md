# Flutter website 官方 agent skills → PlanStar 集成评估（2026-10-11）

> 素材：`_archive_docs/website-main/`（= `github.com/flutter/website` 的一份只读副本，未入库、已 gitignore）。
> 目标：判断这份 Flutter 官方文档仓里**哪些东西能集成进 PlanStar 的运行时 agent**，让它写 Flutter/Dart 更地道。
> 证据一律「文件:行号」。PlanStar 侧路径相对仓库根；中间件侧路径在 `~/.pub-cache/hosted/pub.dev/genkit_middleware-0.6.1/`。
> 许可：该仓 content 为 **CC-BY-3.0**、code 为 **BSD**（`_archive_docs/website-main/LICENSE:1-4`）——skill 的 Markdown 正文属 content，可复用但**须署名**。

---

## 0. 一句话结论

PlanStar 的运行时 agent **早就接好了 skills 机制**（`SkillsPlugin` + `skills(skillPaths:)`，见 §2），而 Flutter 官方仓里的 `.agents/skills/*/SKILL.md` **正好就是这个机制吃的格式**。所以最高价值、最低成本的动作不是"改代码"，而是**把这几份官方 skill 装进 PlanStar 的 skillsRoot**（P0-1）；真正要写代码的只有两处兼容缺口的修补（P0-2）。其余（内置精选 skill、instructions 发现 `.agents/skills`、llms.txt 文档源）是 P1/P2。

---

## 1. `_archive_docs/website-main` 里有什么（清点）

| 资产 | 位置 | 规模 | 对 PlanStar 的价值 |
| --- | --- | --- | --- |
| **官方 agent skills** | `.agents/skills/` | 8 个 skill | ★★★ 直接可装进运行时 agent |
| ├ write-flutter | `.agents/skills/write-flutter/SKILL.md` + `references/{widgets,state-and-architecture,testing,performance,design,layout}.md` | SKILL 140 行 + 6 篇 ref ~726 行 | ★★★ Flutter 代码地道性 |
| ├ write-dart | `.agents/skills/write-dart/SKILL.md` + `references/{style,documentation,usage,design,modern-dart}.md` | SKILL 138 行 + 5 篇 ref ~694 行 | ★★★ Dart 代码地道性（含 3.12/3.13 新语法） |
| ├ validate-pr / format-markdown / write-technical-docs / update-llms-text / update_whats_new / contribute-blog | `.agents/skills/*` | 各 38–209 行 | ★ 多为**文档站自用**（跑 `dash_site`），对 PlanStar 无直接用途，仅作 skill 写法范本 |
| **llms.txt** | `sites/docs/src/content/llms.txt` | 186 行、22 个 `##` section | ★★ 一份人工策展的"给 LLM 看的 Flutter 文档索引" |
| **示例工程** | `examples/`（app-architecture、state_mgmt、testing、perf、cookbook…） | 大 | ★ 参考实现；架构与 PlanStar 不同（用 freezed/provider，PlanStar 用 Riverpod） |
| 文档站本体 | `sites/docs`、`sites/www`（Jaspr 站点） | 数千文件 | ✗ 不迁 |

关键：`write-flutter`/`write-dart` 是 **Flutter 团队自己写给 coding agent 的最佳实践**，措辞是 DO/DON'T/PREFER/AVOID/CONSIDER 分级（`write-flutter/SKILL.md:18-20`），且刻意精炼——这正是能塞进 agent 上下文的形态。

---

## 2. PlanStar 侧的对接面（现状，全部带证据）

### 2.1 运行时 agent 已内建 skills 机制 ✅
- `SkillsPlugin()` 已注册进 Genkit 插件链：`lib/genkit/agent_runtime.dart:941`。
- agent 装配时条件挂 skills 中间件：`skills(skillPaths: [skillsDir.path])`，仅当目录存在（`agent_runtime.dart:1037-1041`）。
- skillsRoot 解析：`skillsDir = settings.skillsRoot ?? <support>/skills`（`agent_runtime.dart:1016-1017`）。
- 设置项与 UI 已存在：`skillsRoot` 字段 `lib/model/app_settings.dart:195`（默认 null）、读写 `:123/:148/:268`；设置界面输入框 `lib/ui/settings/model_settings.dart:224`、保存 `:545`。
- 改 settings 需重启运行时：`agent_runtime.dart:863-867`（`AppSettings.requiresRuntimeRestart`）。

### 2.2 中间件对 skill 的确切契约（决定兼容性）
`genkit_middleware-0.6.1/lib/src/skills_middleware.dart`：
- 扫描 **skillPaths 的一级子目录**（非递归，`dir.list()`），跳过 `.` 开头目录：`:106-107`。
- 每个子目录须含 `SKILL.md`：`:108-109`；**skill 名 = 目录名**（不是 frontmatter 的 name）：`:110`。
- frontmatter 用正则只取 **`name` 与 `description` 各一行**：`:81-82`。
- 暴露 `use_skill` 工具，被调用时返回**整份 SKILL.md 正文**：`:142-159`。
- `<skills>` 系统提示段由中间件在缓存非空时自动写（PlanStar 注释确认：`agent_runtime.dart:84-86, 1039`）。
- 默认 skillPaths 是 `['skills']`：`:73`；`skills(...)` 形参接受 **List**（PlanStar 只传了一个路径）。

### 2.3 instructions 发现链（另一条独立机制）
- 只认 `AGENTS.md` 与 `.agents/AGENTS.md`：`instructionFileNames`，`lib/genkit/instructions.dart:65`。
- 从 fs 根向下遍历、去重、防越权软链、按 8KB/文件 + 24KB/总 截断：`:60-62, :86-152`。
- 注入为首条消息的 `<project-instructions>` 段：`renderInstructions`，`:201-242`。
- 另有用户自写 **instruction cards**（≤10 张、每张 ≤500 字符）：`lib/model/instruction_card.dart:26-31`。
- ⚠️ **instructions 不认 `.agents/skills/**/SKILL.md`**——即本 Flutter 仓那套 skill，走 instructions 通道**读不到**。

### 2.4 工具的路径解析（决定 references 能否跟进去）
- `read`/`write`/`edit`/`glob`/`grep`/`bash` 的相对路径都 **`ws.resolve(...)` 相对 workspace 根**解析：`lib/genkit/tools.dart:186, 254, 346, 547, 602, 713`。

---

## 3. 可集成项（按优先级）

### P0-1 · 把官方 write-flutter / write-dart 装进 skillsRoot（即插即用，先验证再谈改造）
- **素材**：`.agents/skills/write-flutter/`、`.agents/skills/write-dart/`（各含 `SKILL.md` + `references/`）。
- **做法**：拷成 `<skillsRoot>/write-flutter/SKILL.md`、`<skillsRoot>/write-dart/SKILL.md`（skillsRoot 默认 `<support>/skills`，或在 设置→模型 里指到任意目录，`model_settings.dart:224`）。目录名即 skill 名（`skills_middleware.dart:110`）。
- **收益**：PlanStar 运行时 agent（**不是** IDE 助手）在改 Flutter/Dart 工作区时，`<skills>` 段会列出这两个技能，模型可 `use_skill` 拉取官方最佳实践正文；无需改一行 PlanStar 代码。
- **成本**：极低（拷贝 + 因 skillsRoot 变更重启运行时，`agent_runtime.dart:863-867`）。
- **前置**：必须先做 P0-2 修兼容缺口，否则 description 失效、references 读不到（见下）。
- **署名**：CC-BY-3.0，装进去的 SKILL.md 顶部保留一行出处（`github.com/flutter/website`，CC-BY-3.0）。

### P0-2 · 修两处兼容缺口（这是本批唯一需要写代码/做转换的地方）
把官方 skill 直接拷进去会踩两个坑，都源于 §2.2 的中间件契约：

- **缺口 A｜description 折叠块解析失效**：官方用 YAML 折叠块 `description: >-` 多行（`write-flutter/SKILL.md:3-7`），而中间件正则是 `description:\s*(.+)` **只取首行**（`skills_middleware.dart:82`）→ 解析结果变成字面量 `>-`，`<skills>` 段里技能描述为空/无意义，模型**不知道何时该调用**。
  - 修：**安装时预处理**——把折叠 description 拍平成单行再落盘（不改中间件，最省）。
- **缺口 B｜references 相对路径够不到**：SKILL.md 正文让模型"读 `references/widgets.md`"（`write-flutter/SKILL.md:127-140`），但该相对路径会被 `read` 工具按 **workspace 根**解析（`tools.dart:186`），而 skill 在 `<support>/skills` 下、不在 workspace 内 → 跟不进去。
  - 修（择一）：① 安装时把 `references/*.md` **内联**进 SKILL.md（最稳，代价是正文变大，注意 use_skill 返回整份正文 `skills_middleware.dart:158`）；② 给 PlanStar 加一层"skill 导入"动作，落盘时把 references 重写成**绝对路径**；③ 把 skillsRoot 指到 workspace 内（最脏，污染工作区，不推荐）。
- **缺口 C（次要）**：中间件不认 `disable-model-invocation`（`update-llms-text/SKILL.md:4`）——该字段被忽略，技能仍会暴露给模型。只影响那几个"文档站自用"skill；P0-1 不装它们即可规避。

> 推荐形态：写一个**一次性导入脚本/工具**（`tool/` 下），输入 `.agents/skills/<name>/`，输出拍平 description + 内联 references + 加署名头的 `<skillsRoot>/<name>/SKILL.md`。这样缺口 A/B/C 一次解决，且可复用于任何第三方 skill 仓。

### P1-1 · instructions 发现链纳入工作区内的 `.agents/skills/**/SKILL.md`
- **痛点**：越来越多仓库（本 Flutter 仓、Anthropic skills 生态）把 agent 指引放 `.agents/skills/*/SKILL.md`，而 PlanStar 的 instructions 只认 `AGENTS.md`/`.agents/AGENTS.md`（`instructions.dart:65`）→ 在别人的 Flutter 仓里干活时，官方 skill 到不了模型。
- **干净对接点**：`skills(skillPaths:)` 本就吃 **List**（§2.2），PlanStar 现在只传一个路径（`agent_runtime.dart:1041`）。**把当前 workspace 的 `.agents/skills` 也加进 skillPaths** 即可，让中间件顺手扫工作区内的 skill——比往 instructions 里塞全文更契合既有机制。
- **注意**：workspace 内 skill 属"可能不可信的 clone"，须复用 instructions 已有的越权/软链防护思路（`instructions.dart:100, 137-149`），别让工作区里的 skill 把外部文件拉进上下文。
- **成本**：中（多路径 + 安全边界 + 测试）。

### P1-2 · 内置一份"Flutter/Dart 写作"精选 skill（distill，随包发）
- 把 write-flutter/write-dart 的 references（`state-and-architecture.md`、`testing.md`、`performance.md`、`modern-dart.md`）蒸馏成 PlanStar **自带**的一份 skill，首次运行预置到 `<support>/skills`。
- **为什么不塞 `_systemPrompt`**：系统提示是**通用**编码助手（`agent_runtime.dart:51-81`），塞 Flutter 规则会污染非 Flutter 工作区、白烧 token。走 skills 的**按需 `use_skill`** 才对。
- **成本**：中（蒸馏 + 预置逻辑 + 版本更新策略）。

### P2-1 · llms.txt 作为"框架文档索引"能力
- **素材**：`sites/docs/src/content/llms.txt`（186 行 / 22 section，含 "Building AI-powered apps"、"Performance & optimization"、"Testing & debugging" 等）。
- **设想**：给 agent 一个查权威 Flutter 文档的入口（可挂到既有 `lib/genkit/file_search.dart` 的检索面，或一个只读 docs 工具）。
- **诚实边界**：本地只有**索引**，链接全指向 `docs.flutter.dev` 线上；真取正文要联网，是较大特性。价值中、成本高 → P2，先不做。

### P2-2 · 补"改完就验证"的习惯
- 官方两 skill 都强调 format→analyze→test 验证环（`write-flutter/SKILL.md:115-121`、`write-dart/SKILL.md:114-120`）。PlanStar 系统提示已有 bash + `[exit code: N]` 检查（`agent_runtime.dart:69-70`），但没有"改完 Flutter 跑 `flutter test`"的显式习惯。
- 最低成本落法：作为一张 **instruction card**（用户可开关，`instruction_card.dart`）或写进 P1-2 的内置 skill，**不动系统提示**。

---

## 4. 明确不做 / 不建议

- ✗ **把 Flutter 规则塞进通用 `_systemPrompt`**（`agent_runtime.dart:51`）——污染非 Flutter 工作区。
- ✗ **vendoring 整个文档站**（`sites/`，Jaspr + 数千 md）——只需 skills + llms.txt 两类。
- ✗ **照搬 `examples/app-architecture`**——它用 freezed + viewmodel/repository/`Result`/`Command` 模式（`examples/app-architecture/todo_data_service/lib/...`），与 PlanStar 的 Riverpod 注解模式不同，只作**架构参考**，别混进 PlanStar 代码。
- ✗ **装那 6 个文档站自用 skill**（validate-pr/format-markdown/update-llms-text…）——它们跑 `dash_site` CLI，对 PlanStar 无意义。

---

## 5. 建议落地顺序

1. **P0-2 的导入脚本**（`tool/import_agent_skill.dart` 之类）：拍平 description + 内联 references + 加 CC-BY 署名头。→ 有测试更好（对照 `instructions.dart` 的既有单测风格）。
2. **P0-1**：用脚本把 `write-flutter`/`write-dart` 导入 skillsRoot，重启运行时，真机验证 `<skills>` 段出现、`use_skill` 能取到含 references 的完整正文。
3. 视效果决定 **P1-1**（工作区 `.agents/skills` 进 skillPaths）与 **P1-2**（内置精选 skill 随包发）。
4. **P2** 视需求再议。

> 若采纳，按仓库惯例：这属"评估/方案"文档（同 `docs/*-vs-agent-harness-*.md` 一类），不是 ADR。真正动手 P0-2/P1-1 时再立 ARC 类 ADR 并登记 `docs/debt-register.md`。

---

## 6. 落地记录（2026-10-11）

**P0-2 + P0-1 已落地。**

- 新增导入工具 `tool/import_agent_skill.dart`：读一个源 skill 目录，输出符合中间件契约的 `<out>/<name>/SKILL.md`——把 YAML 折叠/字面块 `description` 拍平成单行、把 `references/**.md` 全部内联、加一行 CC-BY 署名注释。纯变换函数（`splitFrontmatter`/`flattenScalar`/`buildImportedSkill`/`collectReferences`）与 IO（`importSkill`/`main`）分离，可单测。
  - 用法：`dart run tool/import_agent_skill.dart --out <skillsRoot> [--origin "<label>"] <srcSkillDir>...`
- 新增测试 `test/import_agent_skill_test.dart`：13 例全绿（折叠/字面/内联/带引号/缺键的 description 拍平、frontmatter 拆分、name 回退目录名、references 内联、temp 树 round-trip、无 SKILL.md 抛错）。
- 已把 `write-flutter`、`write-dart` 导入运行时默认 skillsRoot：`~/Library/Application Support/top.planstar.desktop/skills/{write-flutter,write-dart}/SKILL.md`（34.5KB / 30.7KB，description 均为单行、references 已内联）。
- 门禁：`dart format` + `dart analyze --fatal-infos`（tool+test）干净；`dart tool/check_architecture.dart` = 0 new；`flutter test test/import_agent_skill_test.dart` 全过。

**待用户验证（需重启）**：skills 中间件仅在运行时构造时挂载（`agent_runtime.dart:1041` 的 `if (skillsDir.existsSync())`），而该目录此前不存在——**必须重启 PlanStar**（或触发运行时重建）才会挂上 `use_skill` 与 `<skills>` 段。重启后在代理模式发一句涉及 Flutter 的消息，确认模型能看到并调用 `write-flutter`/`write-dart`。

**尚未做**：P1-2（内置精选 skill 随包发）、P2（llms.txt 文档源、验证环习惯）。这些要动 `lib/`，按 §5 需先立 ARC 类 ADR。

---

## 7. P1-1 落地记录（2026-10-11）

**P1-1 已落地——但落法与 §3 的原设想不同（改为 Design B，见 ADR-0081）。**

§3 P1-1 原设想是「把工作区 `.agents/skills` 加进 `skillPaths`」。深入运行时后发现这条路撞上一条不变量：agent 只 `defineAgent` 一次、`skillPaths` 构造时扫一次就固定（`agent_runtime.dart:1041`），而工作区是**活 setter**、换文件夹刻意**不重建**运行时（`requiresRuntimeRestart` 不含工作区，`app_settings.dart:378`）。要跟随工作区就得每次换文件夹重建运行时，推翻 ADR-0009「单一运行时」的安排——**否决**。

**采纳 Design B：走指令注入通道，做「清单（manifest）」而非塞进 `skillPaths`。**

- `lib/genkit/instructions.dart` 新增 `discoverWorkspaceSkills` + `renderWorkspaceSkills`：扫 `<workspace>/.agents/skills/<dir>/SKILL.md`（照搬中间件口径：一级子目录、须含 `SKILL.md`、跳 `.` 开头），解析 `name`（缺则回退目录名）+ `description`（折叠块拍平），渲染成 `<workspace-skills>` 段——每条 `名字 — 描述 (read \`相对路径\`)`——追加进 `instructionsForWorkspace` 的同一个注入串。
- **清单是指针不是正文**：模型按需用自己的 `read` 工具拉整份 `SKILL.md`。工作区内的 skill 本就在工作区里、`read` 相对工作区根解析（`tools.dart:186`），够得到——这正是 §2.2 缺口 B 里 `<support>/skills` 够不到的反面。
- **对 `agent_runtime.dart` 零改动**：它本就用活工作区根调 `instructionsForWorkspace`（`:1183`）、换文件夹经 `set workspaceRoot→_queueInstructions`（`:1114`）重排，清单免费跟随。
- **安全 + 预算**：复用指令的越权律（`SKILL.md` 软链逃出工作区即跳）；描述截 240 字符、清单封顶 50 条且溢出发声。
- **根因去重**：把 `splitFrontmatter`/`flattenScalar` 从 `tool/import_agent_skill.dart` 抽进 `lib/genkit/skill_frontmatter.dart`，导入工具与运行时清单**共用一份**解析器（工具 `export…show` 再暴露，其测试一字不改）。
- 门禁：`dart format`（0 changed）/ `dart analyze --fatal-infos`（干净）/ `dart tool/check_architecture.dart`（8 recorded, 0 new）/ `flutter test`（instructions_test 新增 `workspace skills` 组 8 例 + import_agent_skill_test 13 例，两文件 32 例全过）。

**待 macOS 真机走查**：打开一个含 `.agents/skills/<name>/SKILL.md` 的工作区，确认 `<workspace-skills>` 清单随首条消息到达、且模型在任务匹配时会 `read` 清单里那份 skill（清单是指针，可靠性是真机问题）。详见 [ADR-0081](adr/ADR-0081-arc-workspace-skills-manifest.md)。
