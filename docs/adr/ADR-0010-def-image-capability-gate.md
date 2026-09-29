# ADR-0010: 图片附件按模型能力门控

- **状态**: IN-PROGRESS（2026-09-29 由 ACCEPTED 推进：实现与测试已合入 develop；余 macOS 真机走查）
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 生产功能 / 幻觉源（模型收到发不出的东西）
- **日期**: 2026-09-29
- **修复 commit**: c34d1a7（能力表）· ac18647（附件名）· 4496677（门控与两处缺陷）
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §7 A8（模型能力位）；实现过程中由新增测试暴露的两处缺陷一并修复

## 背景（Context）

附件是真实功能面：composer 有图片选择、剪贴板粘贴、拖拽三条入口，图片作为 `MediaPart` 随消息发出（`lib/genkit/agent_runtime.dart:815-822`）。但**没有任何一处知道模型能不能收图**：

- `lib/model/known_models.dart` 原本只有 id → 一句话描述；`lib/state/model_directory.dart` 只有 `provider` 与 `selectedModel`。
- 出厂默认是 `deepseek-chat`（`lib/model/model_settings.dart:29`），它没有图像通道。用户默认就会碰到这个组合：贴一张图 → composer 收下、chip 渲染 → 发送 → provider 侧报错。用户看到的是一条与自己刚发的东西无关的失败。
- 更糟的是 `_submit()` 在调用 `onSubmit` **之前**清空了 `_images`（`composer.dart:357-358`），所以这一轮的图片已经没了——重试要重新贴图。这就是评估文档说的"静默丢件"。

实现新测试时又暴露两处同源缺陷（都是"附件这条路没被走完"）：

1. `composer.dart:845` 的发送按钮 `enabled = busy || (!blocked && !_wasEmpty)`，而 `_wasEmpty` 只跟草稿文字（`:306`）。**只贴图不打字时按钮是禁用的**，`_submit()` 本身却允许（`:355` 同时看 `_images`/`_documents`）——纯附件消息根本发不出去，PDF/文本附件同理。
2. `lib/model/attached_image.dart` 的 `_basename` 用 `path.lastIndexOf('/')` 取文件名。三桌面目标（ADR-0003）下 Windows 的 picker 路径是反斜杠，chip 于是显示整条路径。

## 决策（Decision）

**只做一个能力位：`supportsImage`。** 文档里 A8 原名 `supportsImage/Pdf/Video`，但本仓库只有一条 media 通道——PDF 与文本是本地抽成文字再拼进正文（`lib/state/document_extractor.dart`，`pdfrx`），视频附件不存在。给没有消费者的字段建能力位是凭空加抽象，故不实现，写在代码注释里说明为什么。

- `lib/model/known_models.dart` 增加 `bool modelAcceptsImages(LlmProvider, String modelId)`：已知 id 用前缀表匹配（`gpt-4o`/`gpt-4.1`/`gpt-5`/`o3`/`o4`/`claude-`/`gemini-`，dated 变体自动命中）；名字里带 `vision`/`-vl`/`vl-`/`omni` 视为支持；都不匹配时按 provider 家族兜底——Anthropic/Google 为真，OpenAI 兼容端点为假（那可能是任何模型，包括纯文本的 DeepSeek/Qwen）。
- `lib/state/model_directory.dart` 暴露 `bool get acceptsImages`。控制器层不 import UI，只读 model 层，不碰三条不变量。
- `lib/ui/conversation/composer.dart` 把三条入口（选择器、粘贴、拖拽）收进唯一的 `_attachImages()`：模型不支持就**在用户手上拒绝**并给一条说明（`imagesUnsupportedByModel`，en/zh 双键），而不是让它消失。没有 `modelDirectory`（测试/预览）不设门。
- 同一处 `_primary` 的 `enabled` 改为看"草稿或附件"；`AttachedImage.name` 改用 `p.basename`。
- 门控放在 UI 而不只放在 runtime：runtime 拒绝时 chip 已清空，用户要重贴。**代价**是 composer 必须知道当前模型——它已经通过 `ModelDirectory` 知道了，所以没有新管道。

## 后果（Consequences）

- **正面**：默认配置下贴图会立刻得到"这个模型不收图，改用附加文档或去模型菜单选视觉模型"；纯附件消息可发送；Windows 上附件名正确。
- **负面/风险**：能力表是本地知识，会过期。OpenAI 兼容端点上的未知 id 默认按"不收图"处理，用户若用的是视觉模型会被拦——缓解是名字里带 vision/vl/omni 即放行，且提示语直接指名模型 id，用户知道该换什么。没有做设置页覆写（那需要新偏好字段 + 双入口接线，ADR-0006 的律）。
- **中性**：`known_models.dart` 从"只有描述"变成"描述 + 一个能力位"，后续 A2/B2（自动压缩）要的 contextWindow 之类若真要加，这张表就是它该长的地方。

## 验证（Verification）

```
flutter test test/model_directory_test.dart   # 「image capability」4 例：默认模型拒绝 / 目录内视觉模型放行 / 未知 id 按家族 / 名字带 vision 覆盖家族地板
flutter test test/composer_test.dart           # 「the attach gate」3 例：拒绝并说明、视觉模型放行且 name='shot.png'、文档不受门控影响
dart analyze --fatal-infos lib test tool spike # 0 issue
flutter test                                   # 相对基线零新增失败
```

## 关联（Links）

- 代码: `lib/model/known_models.dart`、`lib/state/model_directory.dart`、`lib/ui/conversation/composer.dart`、`lib/model/attached_image.dart`、`lib/l10n/locales.dart`
- 测试: `test/model_directory_test.dart`、`test/composer_test.dart`
- 来源评估: `docs/zcode-vs-agent-harness-2026-09.md` §7 A8
- 关联 ADR: ADR-0003（Windows 路径分隔符缺陷的前提）、ADR-0006（若将来要做能力覆写，必须同时接设置页与快捷菜单）
