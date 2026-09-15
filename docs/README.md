# 项目文档索引（docs/）

本目录承载项目的**决策记录（ADR）**与**技术债登记**。所有审计发现的缺陷、技术债、架构决策在此分类记录、跟踪状态、闭环处理。

## 目录结构

```text
docs/
├── README.md                 # 本文件：规范与流程
├── debt-register.md          # 技术债与缺陷登记表（唯一状态源）
└── adr/
    ├── ADR-0000-template.md  # ADR 模板（经典 0000 号约定）
    ├── ADR-0001-*.md         # 每个问题/决策一篇
    └── ...
```

## 分类标记（Category Codes）

| 代码 | 含义 | 说明 |
| --- | --- | --- |
| SEC | Security 安全 | 密钥泄露、敏感日志、攻击面 |
| CFG | Configuration drift 配置漂移 | 同一配置多处硬编码、版本号漂移 |
| DEF | Defect 生产缺陷 | 影响真实用户的运行时缺陷 |
| ARC | Architecture 架构 | 包结构、分层、模块边界异常 |
| DEP | Dependency 依赖 | 死依赖、版本冲突、冗余包 |
| DEBT | Technical debt 技术债 | 死代码、职责混杂、认知负担 |
| TST | Test 测试评估 | 测试缺失/失效、CI 阻断 |

## 优先级（Priority）

- **P0** — 安全红线 / 评估阻断：不处理则不可上线或不可验证
- **P1** — 生产缺陷：影响真实用户功能
- **P2** — 债务与优化：不影响功能，但持续增加成本/风险

## 影响维度（Impact）

Agent 维护性四维 + 企业级扩展：

- 认知障碍（难以理解）· 上下文膨胀（浪费 Token）· 评估阻断（无法验证）· 幻觉源（诱导 AI 出错）
- 安全合规 · 生产功能

## 状态机（Status Lifecycle）

```text
PROPOSED → ACCEPTED → IN-PROGRESS → RESOLVED
    └─────────┴────────────┴──→ DEFERRED / SUPERSEDED
```

| 状态 | 含义 |
| --- | --- |
| PROPOSED | 已提出，方案待批准 |
| ACCEPTED | 方案已批准（动手写修复代码的前置条件） |
| IN-PROGRESS | 修复中 |
| RESOLVED | 已解决，回填 commit hash 与验证结果 |
| DEFERRED | 明确搁置，须注明重新评估的触发条件 |
| SUPERSEDED | 被新 ADR 替代，须注明替代者编号 |

## 新增 ADR 流程

1. 复制 [adr/ADR-0000-template.md](adr/ADR-0000-template.md) → `adr/ADR-NNNN-<分类小写>-<slug>.md`（NNNN = 当前最大编号 + 1，四位零填充）。
2. 填写背景（必须含证据：文件:行号、grep/构建输出）、决策（多方案须列备选与取舍）、后果、验证方式。
3. 在 [debt-register.md](debt-register.md) 登记表追加一行。
4. 修复实现前置 ACCEPTED；修复合入后置 RESOLVED 并回填 commit。

## 与 .trae 工作流的关系

- `.trae/rules/workflow.md` 关键词路由：「记录技术债 / 登记缺陷 / 新建 ADR」→ 本流程；「查看技术债 / 债务清单 / 已知问题」→ 读 `debt-register.md`。
- 修复任何已登记问题前，先读对应 ADR 并确认状态为 ACCEPTED。

## 参考实践（GitHub 企业级）

- ADR（Nygard 格式）：<https://adr.github.io>
- MADR（Markdown Any Decision Records）：<https://github.com/adr/madr>
