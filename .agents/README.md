# `.agents/` — 工作流与约束技能（第三棵树）

本目录是 PlanStar 的 **agent 技能库**，组织方式学自仓库内两份参考：`_archive_docs/sentry-dart-main/.agents/skills/`（spec → design-first → code-guidelines + test-guidelines → diagnosing-bugs → review 这条流水线）与 `_archive_docs/website-main/.agents/skills/`（write-dart / write-flutter 这类领域技能 + `references/` 渐进披露）。

## 三棵目录的关系（别混）

| 目录 | 装什么 | 谁会读 |
| --- | --- | --- |
| `.qoder/` · `.trae/` | **同步镜像**：3 条 rules（ponytail/workflow/build）+ 25 个通用技能（git-commit、flutter-*、dart-*、ponytail-*、shadcn-ui-flutter）。逐文件一致，改一份必须改另一份 | Qoder / Trae IDE 编码代理 |
| `.agents/skills/` | **本目录**：PlanStar 专属的 5 个工作流/约束技能（spec、design-first、architecture、testing、review），把密集事实放进 `references/` | 编码代理按需加载 **且** PlanStar 运行时 agent |
| `.claude/` | harness 配置：`settings.json` 权限白名单 + 守护生成物的 PreToolUse 钩子 | Claude Code 类 harness |

## ⚠️ 运行时注入契约（ADR-0081 / ADR-0009）

`.agents/skills/*/SKILL.md` 不只是给编码代理看的文档——PlanStar 的 `lib/genkit/instructions.dart` 会把工作区根的一级 `.agents/skills` 发现成 `<workspace-skills>` 清单，随每条会话注入给**运行时 agent**。因此有两条硬约束：

1. **frontmatter 的 `description:` 必须是单行**。ADR-0081 的清单解析用单行正则（`description:\s*(.+)`），YAML 折叠块 `description: >-`（website 那份参考用的写法）会被截成字面量 `>-`，描述丢失，agent 就不知道何时调用这个技能。
2. **只扫一级子目录，每个技能目录必须含 `SKILL.md`**；`.` 开头的目录跳过。技能名取目录 basename。
3. **SKILL.md 正文里的 `references/*.md` 相对链接，运行时 agent 用自己的 `read` 工具按工作区相对路径去取**（工作区内够得着）——所以链接写相对路径即可，但正文要保持精炼，把深度细节放进 references 而不是塞满 SKILL.md。

这些文件经 ADR-0009 也是模型输入：**不要放密钥、内部主机名或任何不该进 prompt 的东西**。

## 技能流水线

```
spec（定「做什么」）→ design-first（定「怎么塑形」）→ architecture + testing（构建约束）→ review（三轴验收）
```

- **spec** — 把模糊诉求或 `docs/debt-register.md` 条目转成可验证的验收标准。
- **design-first** — 动手前定模块、接缝、公开面。
- **architecture** — 实现/重构/评审时的分层与不变量约束集。
- **testing** — 本仓库的测试约定与守卫清单。
- **review** — 对分支 diff 的三轴评审（Standards / Spec / Correctness）。

## 维护

撞到"某条指令本可避免"的墙、文档里的命令/路径写错、或约定已变时，**提议**更新对应文件（照 sentry 的「Maintaining Agent Docs」），不要静默改，也不要塞任务级一次性补丁或 linter 已能拦的东西。
