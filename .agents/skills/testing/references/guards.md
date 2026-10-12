# 不变量 → 守卫文件对照

每条被**专门守卫**的不变量住在一个 `*_test.dart` 里。改对应表面前必跑对应那棵。`flutter test` 会一起跑它们（含 CI）。条数/文件名会随加测试漂移——现场用 `ls test/*_test.dart`、`grep -rln amplified_text_probe.dart test` 数，别抄这张表的快照。

## 架构与分层

| 守的不变量 | 守卫 | ADR |
| --- | --- | --- |
| 七条架构规则（等价 `check_architecture.dart`） | `architecture_check_test.dart` | 0011/0015/0020 |
| 不许再手写第三套点击件（按文件计数） | `tap_affordance_test.dart` | 0021 |
| `DswHoverTap` 指针/键盘/语义/右键四性 | `dsw_hover_tap_test.dart` | 0021 |

## 主题 / 形状 / 时序

| 守的不变量 | 守卫 | ADR |
| --- | --- | --- |
| 令牌取值 + `motion ramp` + 每枚 `DswShape` 有读者 + 字形在阶梯 + 样式名不撒谎 | `theme_token_test.dart` | 0017/0025/0026/0027/0023 |
| 对比度 WCAG 三求值 | `theme_contrast_test.dart`（+ `dart tool/contrast_check.dart`） | 0004 |
| tooltip 延迟只有一处真值（`lib/ui` 出现 `waitDuration` 即红） | `tooltip_timing_test.dart` | 0023 |
| 图标按钮只有一枚（私有件按文件计数 = 侧栏 rail 那一枚例外） | `icon_button_test.dart` | 0024 |
| 半径阶梯对 shad 也成立（桥旋钮 = `DswShape.control`，每处 `ShadDialog` 自报 `radius:`） | `shad_radius_test.dart` | 0029 |
| 菜单只有一层皮（真开菜单读浮起那层） | `menu_chrome_test.dart` | 0028/0036 |
| `lib/ui` 不许留 Material 菜单（+ "扫描看得见菜单"反向证） | `shad_menu_adoption_test.dart` | 0036 B6 |
| 字段/开关/徽标/设置页不各画一套 | `shad_widget_adoption_test.dart`·`settings_shad_adoption_test.dart` | 0036 B7/B9 |

## 放大文本（一把尺子挂满二十一个宿主、每面两档 1.8x/2.2x）

共用探针 `amplified_text_probe.dart`（宿主清单随加挂漂移，`grep -rln amplified_text_probe.dart test` 现场数）。关键面：`app_frame_test`·`workbench_ui_test`·`settings_test`·`plan_workspace_test`·`plan_data_view_test`·`plan_blocks_test`·`block_primitives_test`·`sidebar_test`·`subagent_tab_test`·`diff_tab_test`·`composer_test`·`git_tab_test`（**要假仓库**）·`approval_panel_test`·`input_queue_panel_test`·`free_window_layer_test`·`settings_quick_menu_test`·`chat_view_test`·`details_panel_test`·`feedback_test`·`segmented_test`·`models_endpoint_test`。

**宿主画法坑**：在 `home:` 里写新的 `MediaQueryData(disableAnimations:)` 会连 `textScaler` 一起替换掉整个 data → 尺子量到 1.0 报通过；用 `MediaQuery.of(context).copyWith(…)`，且**新面必须反向验一遍**（钉回死像素看它红）。

## 运行时 / 工具 / 会话

| 守的不变量 | 守卫 | ADR |
| --- | --- | --- |
| 流式拆分性能契约 | `conversation_controller_test.dart` | — |
| 审批判定顺序 + 匹配 + 按工作区落盘 + 面板三按钮 | `tool_gate_test.dart`·`approval_rule_test.dart`·`approval_rule_store_test.dart`·`approval_panel_test.dart` | 0012 |
| 忙时输入队列与交接 | `input_queue_test.dart`·`input_queue_panel_test.dart` | 0013 |
| 文件回退镜像/闸门/范围/淘汰 + pill 出现条件 | `checkpoint_test.dart`·`rewind_pill_test.dart` | 0014 |
| 工具卡读内容不读信封 + 两表面一个读法 | `tool_card_readability_test.dart`·`tool_payload_one_voice_test.dart` | 0031/0035 |
| 一次 `git status` 只有一个持有者 | `git_status_store_test.dart`（八棵）+ `git_status_real_test.dart`（唯一真 spawn git）+ `workbench_ui_test.dart` 那几棵 | 0043 |
| 分组的历史：sidecar/组合/纯函数/画出来那棵 | `session_registry_test.dart`·`session_groups_test.dart`·`relative_time_test.dart`·`workspace_history_test.dart` | 0039 |
| `@` 引用索引/排序/展开 | `mention_test.dart` | — |
| 双树/布局 | `sidebar_state_test.dart`·`split_node_test.dart`·`workbench_ui_test.dart`·`app_frame_test.dart` | 0006 |

## 企划模式（`ls test/plan_*_test.dart` 现数）

工作区模式/记录/编解码/引擎/块树/五投影/库屏：`workspace_mode_test`·`plan_workspace_test`·`plan_object_store_test`·`plan_struct_test`·`plan_filter_engine_test`·`plan_markdown_codec_test`·`plan_codec_envelope_test`·`plan_block_document_test`·`plan_blocks_test`·`plan_data_view_test`·`plan_board_viewer_test`·`plan_all_content_test`·`plan_object_info_test`·`plan_templates_test`·`plan_widget_template_test`·`plan_widgets_test`·`plan_date_gallery_test`·`plan_create_collection_test`·`plan_review_test`。

## i18n / 设置 / 备份

| 守的不变量 | 守卫 | ADR |
| --- | --- | --- |
| 双语键集对齐（`untranslated.json` 空 + `trKey ≡ ARB`） | `l10n_parity_test.dart` | 0008/0082 |
| 零容忍硬编码中文 | `hardcoded_copy_test.dart` | 0080 |
| 每条偏好都要有人读回 + 字段 hint 不许编绝对路径 | `settings_reach_test.dart` | 0022/0033 |
| 语言进得了 overlay | `i18n_overlay_test.dart` | 0032 |
| 备份条目名不许走出它自己的目录（zip-slip） | `backup_paths_test.dart` | 0042 |
| 图标即控件必须自报姓名 | `app_frame_test`·`workbench_ui_test`（`every icon-only control … names itself`） | 0017 S3 |

**反向验证是这张表每一行的隐含要求**——扫描/断言类守卫都要能证明它看得见东西（见 testing SKILL.md「反向验证文化」）。
