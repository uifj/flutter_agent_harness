# ADR-0081: 工作区 `.agents/skills` 走指令注入通道——manifest 而非 skillPaths（不改 agent_runtime）

- **状态**: ACCEPTED（用户在两方案里选了 B；已实施，见「验证」段的门禁与「待 macOS 真机走查」）
- **分类**: ARC
- **优先级**: P1（越来越多仓库把 agent 指引放 `.agents/skills/*/SKILL.md`——`github.com/flutter/website` 自己就是这么发的、Anthropic skills 生态同形——而 PlanStar 的运行时 agent 在别人这样的仓里干活时，这些技能一个都到不了模型）
- **影响维度**: 上下文膨胀 / 幻觉源 / 生产功能
- **日期**: 2026-10-11
- **来源**: `docs/flutter-website-agent-skills-integration-2026-10-11.md` §3 P1-1
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

PlanStar 运行时 agent 的 skill 机制有两条**互不相通**的通道，工作区自带的 `.agents/skills` 哪条都够不到：

1. **中间件通道**（`use_skill` 工具 + `<skills>` 系统提示段）：`SkillsPlugin` 扫的是 `skillPaths`，而 PlanStar 只传一个固定目录——`skillsDir = settings.skillsRoot ?? <support>/skills`（`agent_runtime.dart:1016-1017`），装配时 `skills(skillPaths: [skillsDir.path])`（`agent_runtime.dart:1041`）。这条 `skillPaths` 在 `defineAgent` 那一刻**扫一次就固定**。
2. **指令注入通道**（首条消息的 `<project-instructions>` 段）：只认 `AGENTS.md` 与 `.agents/AGENTS.md`（`instructions.dart:65` 的 `instructionFileNames`），**不认 `SKILL.md`**。

关键的架构约束（决定这不是"加一行 skillPaths"就完事）：agent 只 `defineAgent` **一次**，工作区是**活 setter**——`set workspaceRoot` 触发 `_queueInstructions()`（`agent_runtime.dart:1114`），`AppScope.save` 只是翻这个 setter 并起新会话；而 `requiresRuntimeRestart` **刻意不含**工作区变更（`app_settings.dart:378`）。所以换文件夹**不重建运行时**，一个构造时固定的 `skillPaths` 无法跟着工作区走。

## 决策（Decision）

**采纳 B：把工作区的 skill 作为「清单（manifest）」注入既有指令通道，而不是把工作区加进 `skillPaths`。**

- **为什么不选 A（把 `<workspace>/.agents/skills` 加进 skillPaths）**：`skillPaths` 构造时扫一次就固定，要让它跟随工作区，就得在每次换文件夹时**重建运行时**——这既推翻 ADR-0009 立下的"单一运行时、工作区是活 setter"这条安排，也推翻 `requiresRuntimeRestart` 对工作区变更的刻意排除。为一个清单去弯曲两条不变量，不划算。**否决。**

- **B 的机制**：新增 `discoverWorkspaceSkills`（`instructions.dart:297`）扫 `<workspace>/.agents/skills/<dir>/SKILL.md`——**照搬中间件的扫描口径**（只一级子目录、每个须含 `SKILL.md`、跳过 `.` 开头目录），但读它是为了列清单，不是注册 `use_skill`。解析 frontmatter 的 `name`（缺则回退目录名，与中间件同名口径）与 `description`（折叠块拍平成一行）。`renderWorkspaceSkills`（`instructions.dart:358`）把它们渲染成 `<workspace-skills>` 段，每条 `名字 — 描述 (read \`相对路径\`)`，追加进 `instructionsForWorkspace` 返回的**同一个注入串**（`instructions.dart:398`）。

- **对 `agent_runtime.dart` 零改动**：它本就用**活的工作区根**调 `instructionsForWorkspace`（`agent_runtime.dart:1183`），并在每次工作区切换时经 `set workspaceRoot → _queueInstructions()`（`:1114`）重排——所以清单**免费跟着工作区切换走**。

- **清单而非正文**：模型按需用自己的 `read` 工具拉整份 `SKILL.md`，而 `read` 相对工作区根解析（`tools.dart:186`）——工作区内的 skill **本就在工作区里**，够得到（这与 `<support>/skills` 里的 skill 相反，那些在工作区外，正是评估文档 §2.2 缺口 B）。注入块因此是**指针，不是载荷**。

- **安全**：复用指令发现已有的越权律——`SKILL.md` 的规范化目标若逃出工作区就跳过（`_isWithin`），与被软链的 `AGENTS.md` 同一条处置。clone 来的仓不能借一个软链把外部文件拉进模型上下文。

- **预算**：每条 `description` 截到 240 字符、清单封顶 50 条并在溢出时**说话**（"…and N more; `glob` …"），与指令的 8KB/文件 + 24KB/总 同一种"一篇超长 README 不许吃掉上下文窗口"的自觉。

- **共享解析器（根因，不留两份）**：把 `splitFrontmatter`/`flattenScalar` 从 `tool/import_agent_skill.dart` 抽进 `lib/genkit/skill_frontmatter.dart`，由**导入工具与运行时清单两处共同 import**。于是一个 skill 的 `name`/`description` 无论被导入到 `<support>/skills` 还是从工作区列进清单，**解析结果必然一致**；否则两份解析器会各自腐烂，同一个 skill 两种读法。工具用 `export … show` 再暴露，`test/import_agent_skill_test.dart` 的 `show` 一字不改。

- **`isInjectedPart` 认新标签**（`instructions.dart:180`）：只有 skill、没有 `AGENTS.md` 的工作区，其注入串以 `<workspace-skills>` 开头，必须被会话标题的取词过滤掉，与 `<project-instructions>` 同款处置。

## 后果（Consequences）

- **正面**: 自带 `.agents/skills` 的仓库（Flutter 官方仓、Anthropic skills 生态）现在能到达运行时 agent，且**跟着换文件夹免费生效**、不重建运行时、不给 `agent_runtime.dart` 加任何新面；复用已被单测覆盖的指令通道与其越权/预算防护。
- **负面/风险**: 清单是**指针**——模型得自己决定去 `read` 那份 `SKILL.md`（不同于中间件的 `use_skill` 是一枚模型被系统提示引导去调的一等工具）。"模型是否会可靠地在任务匹配时去 read 这个路径"是**真机问题**（待验证）。若用户把 `skillsRoot` 指到 `<workspace>/.agents/skills`，同一 skill 会同时出现在中间件 `<skills>` 与本清单——**良性冗余**，不去重（YAGNI）。
- **中性**: `lib/genkit/skill_frontmatter.dart` 是 lib 与 tool 共享的新纯 Dart 库；`instructions.dart` 在指令文件之外多了一件事（skill 清单），仍留在同一文件，因为两者**共乘一个注入串**。

## 验证（Verification）

- `test/instructions_test.dart` 新增 `workspace skills` 组（8 例，真临时树）：折叠描述拍平 + 路径为工作区相对、name 回退目录名、软链越权跳过、隐藏目录与无 `SKILL.md` 目录跳过、清单封顶 + 溢出计数、描述截断、manifest 渲染形状与空则 null、以及"指令 + skill 同乘一块"与"仅 skill 也注入且被 `isInjectedPart` 认出"。
- `test/import_agent_skill_test.dart`（13 例）在抽取后仍全绿——工具经 `export` 再暴露被移走的解析器。
- 门禁：`dart format`（0 changed）/ `dart analyze --fatal-infos`（干净）/ `dart tool/check_architecture.dart`（8 recorded, 0 new）/ `flutter test` 两个文件（32 例全过）。
- **待 macOS 真机走查**：打开一个含 `.agents/skills/<name>/SKILL.md` 的工作区，确认 `<workspace-skills>` 清单随首条消息到达、且模型在任务匹配时会 `read` 清单里列出的那份 skill。（`<support>/skills` 的中间件 `<skills>`/`use_skill` 通道是另一条，未受影响。）

## 关联（Links）

- 代码: `lib/genkit/instructions.dart:257-413`（`WorkspaceSkill`/`discoverWorkspaceSkills`/`renderWorkspaceSkills`/`instructionsForWorkspace`/`isInjectedPart`）、`lib/genkit/skill_frontmatter.dart`（共享解析器）、`tool/import_agent_skill.dart`（改为 import + re-export 它）、`lib/genkit/agent_runtime.dart:1114`·`:1183`（让本 ADR 对运行时零改动的那道缝）
- 关联 ADR: ADR-0009（工作区指令注入——本 ADR 共乘其通道与重排时机）、ADR-0015（运行时脱离 Flutter——新库是纯 Dart，维持 `lib/genkit` 不碰 Flutter）
- 上游研究: `docs/flutter-website-agent-skills-integration-2026-10-11.md` §3 P1-1
