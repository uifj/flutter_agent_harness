# ADR-0077: 每工作区配置目录（对标 .obsidian）

- **状态**: PROPOSED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-07
- **来源**: 用户产品目标（"根据项目选择的工作区进行类似 .obsidian 参数加载"）+ 本机 Obsidian vault 实测
- **修复 commit**: —

## 背景（Context）

- **对标事实（本机实测 `/Users/uifj/Personal/in-sail-obsidian/.obsidian`）**：一个 vault 一个点目录，**按关注点一文件**（`app.json`/`appearance.json`/`core-plugins.json`/`workspace-mobile.json`），全是 JSON；**默认值不落盘**（`app.json`/`appearance.json` 都是空 `{}`）；**UI 状态与笔记内容彻底分离**（`workspace-mobile.json` 只存布局树 split/tabs/leaf + 每叶插件状态 + active + lastOpenFiles，笔记永远是 vault 里的裸 md）；桌面端另有 `workspace.json`（该 vault 是移动端用的，没有）。
- **本仓现状**：工作区即 vault（`lib/ui/plan/plan_workspace.dart:10-12` 的头部注释——vault 就是 agent 的 `workspaceRoot`，没有第二个目录、没有第二道授权）。应用级配置全在 `<support>/`（settings/prefs/workbench/sessions/checkpoints），**没有 vault 级配置层**：换一个工作区，树展开态、偏好全部回到默认。
- **需求形状**：用户要的是"换工作区 → 该工作区自己的配置跟着走"，即 Obsidian 的 vault 语义。

## 决策（Decision）

**方向（待 ACCEPTED 后细化施工）**：

- **`<workspaceRoot>/.planstar/` 点目录承载 vault 级配置**，形态照抄 Obsidian 的三条律：一关注点一 JSON（如 `vault.json` 起步）、**默认值不落盘**（文件缺失=全默认，写只在用户实际改了什么之后）、**UI 状态与笔记内容分离**（目录里永远不出现笔记正文）。
- **安全边界（写死）**：密钥/账号/模型 key 绝不进 `.planstar/`——它们留在 `<support>/`（ADR-0012 审批规则的先例：不往用户工作区写敏感物）；`.planstar/` 只放"这个 vault 的界面与行为偏好"。
- **进什么（首批候选，施工时定稿）**：vault 树展开态、笔记排序、最近打开的笔记——即今天无处安放的"这个 vault 的视图状态"；企划集合/记录的持久化**不迁**（ADR-0071 已落 drift `<support>/planstar.db`，那是对象数据不是配置）。
- **与 git 的关系要拍板**：`.planstar/` 出现在用户仓库的 `git status` 里（ADR-0043 的徽标体系会照见它）。Obsidian 生态对 `.obsidian/` 的惯例是"可选提交"；本仓默认**不代用户写 .gitignore**（那是用户的仓库决策），但文档要说明这一点，且配置写入走防抖（沿 ADR-0075 的保存器形态）。
- **备选不选**：全局 `~/.planstar/<工作区名>/`（用户原话的字面形状）——把配置放仓库外会让"拷贝 vault = 拷走配置"失效，与 Obsidian 的 vault 自包含语义相反；仅在"工作区只读/不欢迎落文件"的场景才值得回头考虑。

## 后果（Consequences）

- **正面（若实施）**：对标目标 9；多 vault 用户的视图状态各归各；vault 自包含（拷目录即拷走全部状态）。
- **负面/风险**：往用户仓库里写文件是一个**能力边界**动作（用户可能不欢迎）；`.planstar/` 会进 git 徽标体系与 agent 的 glob/grep 视野（工具要不要默认忽略它，施工时定）；与 `workspaceRoot` 授权恢复的时序耦合（配置读取必须在 bookmark 恢复之后，`main()` 的既有律）。
- **中性**：`settings_store` 同族的原子写与防抖先例可直接复用。

## 验证（Verification）

实施后：切工作区 → 各自配置互不串；删掉 `.planstar/` → 应用照常（全默认，不报错）；配置写入为 tmp+rename 原子写 + 防抖；四道门禁同口径。

## 关联（Links）

- 代码: `lib/state/settings_store.dart`（原子写先例）、`lib/state/workbench_store.dart`（防抖写盘先例）、`lib/ui/plan/plan_vault_tree.dart`（展开态等视图状态的现状归属）
- 关联 ADR: ADR-0075（保存器形态的来源）、ADR-0071（企划对象数据已落 drift，不在本 ADR 范围）、ADR-0012（不往用户工作区写敏感物的先例）、ADR-0043（git 徽标——`.planstar/` 会照见）
- 研究: 本机 `.obsidian` 四文件实测（见背景）
