# BaseComponent Flutter 组件使用说明

## 目录

- [Avatar](#avatar)
- [Button](#button)
- [Toast](#toast)
- [AlertDialog](#alertdialog)
- [Label](#label)
- [Badge](#badge)
- [Switch](#switch)
- [Bubble](#bubble)
- [ActionSheet](#actionsheet)
- [主题语义化样式](#主题语义化样式)

---

## Avatar

### 用法

#### 便捷用法
```dart
Avatar.image(
  url: 'https://example.com/avatar.jpg',
  name: '张三',
  size: AvatarSize.m,
)
```

#### 完整用法
```dart
Avatar(
  content: AvatarImageContent(
    url: 'https://example.com/avatar.jpg',
    name: '张三',
  ),
  size: AvatarSize.m,        // .xs / .s / .m / .l / .xl / .xxl
  shape: AvatarShape.round,  // .round / .roundedRectangle / .rectangle
  status: AvatarStatus.online, // .none / .online / .offline
  badge: CountBadge(5),      // CountBadge / DotBadge / TextBadge
  onClick: () { /* ... */ },
)
```

#### 不同内容类型
```dart
// 文字头像
Avatar(
  content: AvatarTextContent('李'),
  size: AvatarSize.l,
)

// 符号头像
Avatar(
  content: AvatarSymbolContent(),
  size: AvatarSize.xl,
)

// 本地图片头像
Avatar(
  content: AvatarLocalContent('assets/avatar.png'),
  size: AvatarSize.m,
)
```

### 参数说明
- `content`: 头像内容（AvatarImageContent/AvatarTextContent/AvatarSymbolContent/AvatarLocalContent）
- `size`: 头像尺寸（xs:24 / s:32 / m:40 / l:48 / xl:64 / xxl:96）
- `shape`: 头像形状（圆形/圆角矩形/矩形）
- `status`: 在线状态点（无/在线/离线）
- `badge`: 角标（计数/圆点/文本）
- `onClick`: 点击回调（可选）

### 字体适配
头像内文字的字体会根据 `size` 自动适配，无需手动指定。

### 主题环境
需要在应用根部包裹 `BaseThemeProvider` 来提供主题支持。

---

## Button

### 设计原则

所有按钮都遵循统一的设计原则：
- **默认构造函数只允许传入核心参数**
- **高级用法通过 `buttonContent` 静态方法支持所有类型的内容**

### AtomicxFilledButton

#### 基础用法（默认构造函数）
```dart
// 只能传入文本
AtomicxFilledButton(
  text: '填充按钮',
  size: ButtonSize.l,
  colorType: ButtonColorType.primary,
  onClick: () { /* ... */ },
)
```

#### 高级用法（图标+文字）
```dart
// 纯文本
AtomicxFilledButton.buttonContent(
  buttonContent: TextOnlyContent('文本'),
  onClick: () { /* ... */ },
)

// 纯图标
AtomicxFilledButton.buttonContent(
  buttonContent: IconOnlyContent(Icon(Icons.star)),
  onClick: () { /* ... */ },
)

// 图标+文字
AtomicxFilledButton.buttonContent(
  buttonContent: IconWithTextContent(
    text: '收藏',
    icon: Icon(Icons.star),
    iconPosition: ButtonIconPosition.start,
  ),
  onClick: () { /* ... */ },
)
```

### AtomicxOutlinedButton

#### 基础用法（默认构造函数）
```dart
// 只能传入文本
AtomicxOutlinedButton(
  text: '轮廓按钮',
  size: ButtonSize.l,
  colorType: ButtonColorType.primary,
  onClick: () { /* ... */ },
)
```

#### 高级用法（图标+文字）
```dart
// 纯文本
AtomicxOutlinedButton.buttonContent(
  buttonContent: TextOnlyContent('文本'),
  onClick: () { /* ... */ },
)

// 纯图标
AtomicxOutlinedButton.buttonContent(
  buttonContent: IconOnlyContent(Icon(Icons.settings)),
  onClick: () { /* ... */ },
)

// 图标+文字
AtomicxOutlinedButton.buttonContent(
  buttonContent: IconWithTextContent(
    text: '删除',
    icon: Icon(Icons.delete),
    iconPosition: ButtonIconPosition.end,
  ),
  onClick: () { /* ... */ },
)
```

### AtomicxIconButton

#### 基础用法（默认构造函数）
```dart
// 只能传入图标
AtomicxIconButton(
  icon: Icon(Icons.star),
  size: ButtonSize.m,
  colorType: ButtonColorType.primary,
  onClick: () { /* ... */ },
)
```

#### 高级用法（图标+文字）
```dart
// 纯文本（会自动转换为 AtomicxFilledButton）
AtomicxIconButton.buttonContent(
  content: TextOnlyContent('文本'),
  onClick: () { /* ... */ },
)

// 纯图标
AtomicxIconButton.buttonContent(
  content: IconOnlyContent(Icon(Icons.download)),
  onClick: () { /* ... */ },
)

// 图标+文字
AtomicxIconButton.buttonContent(
  content: IconWithTextContent(
    text: '分享',
    icon: Icon(Icons.share),
    iconPosition: ButtonIconPosition.end,
  ),
  onClick: () { /* ... */ },
)
```

### 参数说明
- `text`: 按钮文本（AtomicxFilledButton 和 AtomicxOutlinedButton 的默认构造函数）
- `icon`: 按钮图标（AtomicxIconButton 的默认构造函数）
- `buttonContent`/`content`: 按钮内容（TextOnlyContent/IconOnlyContent/IconWithTextContent）
- `size`: 按钮尺寸（xs:24 / s:32 / m:40 / l:48）
- `colorType`: 语义色类型（primary / secondary / danger）
- `enabled`: 是否可用（默认 true）
- `onClick`: 点击回调

### ButtonContent 类型
- `TextOnlyContent(text)`: 纯文本内容
- `IconOnlyContent(icon)`: 纯图标内容
- `IconWithTextContent(text: text, icon: icon, iconPosition: position)`: 图标+文字内容

### 字体适配
按钮字体会根据 `size` 自动适配，无需手动指定。

### 迁移指南
```dart
// 旧用法（已移除）
AtomicxFilledButton.text(text: '文本', onClick: () {})
AtomicxFilledButton.icon(icon: Icon(Icons.star), onClick: () {})
AtomicxFilledButton.iconWithText(icon: Icon(Icons.star), text: '文本', onClick: () {})

// 新用法
AtomicxFilledButton(text: '文本', onClick: () {})
AtomicxFilledButton.buttonContent(buttonContent: IconOnlyContent(Icon(Icons.star)), onClick: () {})
AtomicxFilledButton.buttonContent(buttonContent: IconWithTextContent(icon: Icon(Icons.star), text: '文本'), onClick: () {})
```

---

## Toast

### 用法

#### 便捷用法
```dart
Toast.loading(context, '加载中...');
Toast.info(context, '信息提示');
Toast.success(context, '操作成功');
Toast.warning(context, '警告信息');
Toast.error(context, '错误信息');
Toast.simple(context, '纯文字提示');
```

#### 完整用法
```dart
Toast.show(
  context,
  '自定义内容',
  type: ToastType.info,
  duration: Duration(seconds: 2),
);
```

#### 手动控制
```dart
// 隐藏Toast
Toast.hide();
```

### 参数说明
- `context`: 上下文
- `message`: 提示内容
- `type`: Toast类型（.loading / .info / .success / .warning / .error / .help）
- `duration`: 显示时长（默认2秒）

### Toast类型
- `loading`: 加载中（带旋转动画）
- `info`: 信息提示（蓝色图标）
- `success`: 成功提示（绿色图标）
- `warning`: 警告提示（橙色图标）
- `error`: 错误提示（红色图标）
- `help`: 帮助提示（蓝色图标）

### 主题环境
Toast 组件自动适配深色/浅色主题，无需额外配置。

---

## AlertDialog

### 用法

#### 便捷用法
```dart
AtomicxAlertDialog(
  isVisible: showAlert,
  message: '操作成功！',
  onConfirm: () {
    setState(() => showAlert = false);
  },
  onDismiss: () {
    setState(() => showAlert = false);
  },
)
```

#### 完整用法
```dart
AtomicxAlertDialog(
  isVisible: showAlert,
  title: '确认操作',
  message: '是否确认执行此操作？这个操作不可撤销。',
  confirmText: '确认',
  cancelText: '取消',
  onConfirm: () {
    setState(() => showAlert = false);
    // 执行确认操作
  },
  onCancel: () {
    setState(() => showAlert = false);
    // 执行取消操作
  },
  onDismiss: () {
    setState(() => showAlert = false);
  },
)
```

#### 在Stack中使用
```dart
Stack(
  children: [
    // 你的页面内容
    Scaffold(
      // ...
    ),
    // 对话框
    AtomicxAlertDialog(
      isVisible: showAlert,
      title: '提示',
      message: '这是一个对话框',
      onConfirm: () {
        setState(() => showAlert = false);
      },
      onDismiss: () {
        setState(() => showAlert = false);
      },
    ),
  ],
)
```

### 参数说明
- `isVisible`: 是否显示对话框
- `title`: 标题（可选）
- `message`: 内容（可选，支持长文本滚动）
- `confirmText`: 确认按钮文字（默认"我知道了"）
- `cancelText`: 取消按钮文字（可选）
- `onConfirm`: 确认回调
- `onCancel`: 取消回调（可选）
- `onDismiss`: 点击遮罩关闭回调

### 特性
- 支持长文本内容自动滚动
- 按钮响应区域完全覆盖
- 底部圆角与按钮响应区域一致
- 自动适配主题色彩

---

## Label

### 用法

#### 便捷用法
```dart
TitleLabel(size: LabelSize.small, text: '主标题-小');
SubTitleLabel(size: LabelSize.medium, text: '副标题-中');
ItemLabel(size: LabelSize.large, text: '条目-大');
DangerLabel(size: LabelSize.small, text: '警告-小');
```

#### 标签用法
```dart
TagLabel(
  size: LabelSize.medium,
  text: '标签',
  colorType: TagColorType.blue,
  icon: 'assets/icon.png',          // 可选
  iconPosition: IconPosition.start, // 可选
);
```

#### 自定义用法
```dart
CustomLabel(
  text: '自定义Label',
  font: TextStyle(fontSize: 16),
  textColor: Colors.red,
  backgroundColor: Colors.yellow,
  lineLimit: 2,
  icon: 'assets/icon.png',          // 可选
  iconPosition: IconPosition.end,   // 可选
);
```

### 参数说明
- `size`: 标签尺寸（.small / .medium / .large）
- `text`: 文本内容
- `colorType`: 标签颜色类型（TagLabel专用：.white / .blue / .green / .gray / .orange / .red）
- `font`: 字体（仅 CustomLabel 支持）
- `textColor`: 文字颜色（CustomLabel 支持自定义，其它自动适配主题）
- `backgroundColor`: 背景色（CustomLabel 支持自定义，其它自动适配主题）
- `lineLimit`: 行数限制（默认1，CustomLabel可自定义）
- `icon`: 图标（assets图片名，CustomLabel/TagLabel 支持）
- `iconPosition`: 图标位置（.start / .end）

### 字体适配
Label 字体会根据 `size` 和类型自动适配，无需手动指定。

---

## Badge

### 用法

#### 基础用法
```dart
AtomicxBadge(text: '99+');
AtomicxBadge(text: '新消息');
AtomicxBadge(type: BadgeType.dot);
```

#### 与其他组件组合
```dart
Avatar(
  content: AvatarTextContent('李'),
  size: AvatarSize.l,
  badge: CountBadge(5),
)
```

### 参数说明
- `text`: 显示文本（可选）
- `type`: 徽章类型（.text / .dot）

### 特性
- 文本为空或类型为dot时显示圆点
- 自动适配主题色彩
- 支持长文本省略

---

## Switch

### 用法

#### 基础用法
```dart
BasicSwitch(
  checked: isOn,
  onCheckedChange: (value) {
    setState(() => isOn = value);
  },
)
```

#### 完整用法
```dart
CustomSwitch(
  checked: isOn,
  onCheckedChange: (value) {
    setState(() => isOn = value);
  },
  enabled: true,
  loading: false,
  size: SwitchSize.l,              // .s / .m / .l
  type: SwitchType.withText,       // .basic / .withText / .withIcon
)
```

### 参数说明
- `checked`: 当前开关状态（bool）
- `onCheckedChange`: 状态变更回调 `(bool) -> void`
- `enabled`: 是否可用（默认 true）
- `loading`: 是否显示加载动画（默认 false）
- `size`: 尺寸（s:26×16 / m:32×20 / l:40×24）
- `type`: 展示类型（基础/带文字/带图标）

### 特性
- 支持平滑动画过渡
- 文字显示在合适位置（不被滑块遮挡）
- 支持加载状态显示
- 自动适配主题色彩

---

## Bubble

### 用法

#### 预设样式
```dart
LeftBottomSquareBubble(
  backgroundColor: Colors.green,
  child: Text('左下直角气泡'),
)

RightBottomSquareBubble(
  backgroundColor: Colors.blue,
  child: Text('右下直角气泡'),
)

AllRoundBubble(
  backgroundColor: Colors.orange,
  child: Text('全圆角气泡'),
)

LeftTopSquareBubble(
  backgroundColor: Colors.purple,
  child: Text('左上直角气泡'),
)

RightTopSquareBubble(
  backgroundColor: Colors.pink,
  child: Text('右上直角气泡'),
)
```

#### 自定义用法
```dart
Bubble(
  bubbleColorType: BubbleColorType.filled,    // .filled / .outlined / .both
  backgroundColor: Colors.gray,
  highlightColors: [Colors.gray, Colors.white], // 可选，渐变色
  radii: [18, 18, 0, 18],                    // 四角圆角 [左上, 右上, 右下, 左下]
  borderColor: Colors.red,                   // 可选，描边色
  borderWidth: 2,                           // 可选，描边宽度
  child: Text('自定义内容'),
)
```

### 参数说明
- `bubbleColorType`: 气泡类型（.filled 填充，.outlined 描边，.both 填充+描边）
- `backgroundColor`: 背景色
- `highlightColors`: 渐变色数组（可选）
- `radii`: 四角圆角半径 [左上, 右上, 右下, 左下]
- `borderColor`: 边框颜色（可选）
- `borderWidth`: 边框宽度（可选）
- `child`: 气泡内容

### 预设样式说明
- `LeftBottomSquareBubble`: 左下角直角，其他圆角
- `RightBottomSquareBubble`: 右下角直角，其他圆角
- `AllRoundBubble`: 全圆角
- `LeftTopSquareBubble`: 左上角直角，其他圆角
- `RightTopSquareBubble`: 右上角直角，其他圆角

---

## ActionSheet

### 用法

#### 基础用法
```dart
ActionSheet.show(
  context,
  title: '选择操作',
  actions: [
    ActionSheetItem(
      title: '编辑',
      onTap: () {
        // 编辑操作
      },
    ),
    ActionSheetItem(
      title: '删除',
      onTap: () {
        // 删除操作
      },
      isDestructive: true,  // 危险操作，红色文字
    ),
  ],
)
```

#### 完整用法
```dart
ActionSheet.show(
  context,
  title: '请选择操作',
  message: '选择你要执行的操作',
  actions: [
    ActionSheetItem(
      title: '复制',
      onTap: () {
        // 复制操作
      },
    ),
    ActionSheetItem(
      title: '分享',
      onTap: () {
        // 分享操作
      },
    ),
    ActionSheetItem(
      title: '删除',
      onTap: () {
        // 删除操作
      },
      isDestructive: true,
    ),
    ActionSheetItem(
      title: '禁用项',
      onTap: () {
        // 不会执行
      },
      isDisabled: true,
    ),
  ],
  cancelText: '取消',
  showCancel: true,
)
```

### 参数说明
- `context`: 上下文
- `title`: 标题（可选）
- `message`: 描述信息（可选）
- `actions`: 操作项列表
- `cancelText`: 取消按钮文字（可选）
- `showCancel`: 是否显示取消按钮（默认 true）

### ActionSheetItem 参数
- `title`: 选项标题
- `onTap`: 点击回调
- `isDestructive`: 是否为危险操作（红色文字，默认 false）
- `isDisabled`: 是否禁用（默认 false）

### 特性
- 从底部弹出的模态框
- 支持危险操作样式
- 支持禁用状态
- 自动适配主题色彩
- 支持取消操作

---

## 主题语义化样式

### 使用方式
```dart
final colors = BaseThemeProvider.colorsOf(context);
final fonts = FontScheme.body1Medium;
```

### 颜色系统
主题提供了完整的语义化颜色系统，包括：

#### 文本颜色
- `textColorPrimary`: 主要文本色
- `textColorSecondary`: 次要文本色
- `textColorTertiary`: 三级文本色
- `textColorDisable`: 禁用文本色
- `textColorButton`: 按钮文本色
- `textColorLink`: 链接文本色
- `textColorWarning`: 警告文本色
- `textColorSuccess`: 成功文本色
- `textColorError`: 错误文本色

#### 背景颜色
- `bgColorDefault`: 默认背景色
- `bgColorTopBar`: 顶部栏背景色
- `bgColorDialog`: 对话框背景色
- `bgColorBubbleOwn`: 自己的气泡背景色
- `bgColorBubbleReciprocal`: 对方的气泡背景色

#### 按钮颜色
- `buttonColorPrimaryDefault`: 主按钮默认色
- `buttonColorSecondaryDefault`: 次按钮默认色
- `switchColorOn`: 开关开启色
- `switchColorOff`: 开关关闭色

#### 边框颜色
- `strokeColorPrimary`: 主要边框色
- `strokeColorSecondary`: 次要边框色
- `strokeColorModule`: 模块边框色

### 字体系统
提供了完整的字体规范：

#### 标题字体
- `title1Bold` / `title1Medium` / `title1Regular`
- `title2Bold` / `title2Medium` / `title2Regular`
- `title3Bold` / `title3Medium` / `title3Regular`
- `title4Bold` / `title4Medium` / `title4Regular`

#### 正文字体
- `body1Bold` / `body1Medium` / `body1Regular`
- `body2Bold` / `body2Medium` / `body2Regular`
- `body3Bold` / `body3Medium` / `body3Regular`
- `body4Bold` / `body4Medium` / `body4Regular`

#### 说明字体
- `caption1Bold` / `caption1Medium` / `caption1Regular`
- `caption2Bold` / `caption2Medium` / `caption2Regular`
- `caption3Bold` / `caption3Medium` / `caption3Regular`
- `caption4Bold` / `caption4Medium` / `caption4Regular`

### 主题环境配置
```dart
MaterialApp(
  home: BaseThemeProvider(
    child: YourApp(),
  ),
)
```

### 注意事项
1. 所有组件都需要在 `BaseThemeProvider` 环境下使用
2. 建议使用语义化的颜色和字体，而不是硬编码的颜色值
3. 组件会自动适配深色/浅色主题
4. 字体大小会根据组件尺寸自动适配

--- 