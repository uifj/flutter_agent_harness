# ADR-0079: 应用内更新检查——GitHub Releases 为版本源

- **状态**: ACCEPTED（用户批准评估路线图 §5 第 1 项,hunnu-app-osos 评估 `docs/hunnu-app-osos-vs-planstar-2026-10.md` §1.1 的设计移植;零代码照抄）
- **分类**: ARC
- **优先级**: P1（「发现新版本」菜单现为死门——本仓 GitHub 仓库无公开 releases 页内容可看,点击即落空）
- **影响维度**: 生产功能
- **日期**: 2026-10-07
- **来源**: hunnu_app_osos 评估 §1.1（`lib/core/update/update_service.dart` 的六件套形态）+ ADR-0072 遗留的空壳菜单 + ADR-0045 生产化总纲
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

ADR-0072 把「发现新版本」放进应用菜单,但 onTap 只是 `onOpenLink(AppMeta.releasesUrl)`——本仓没有可浏览的
releases 页,菜单是死门。hunnu_app_osos 的 `UpdateService` 证明这件事的最小完整形态是六件套:远端版本源、
语义化比较、跳过本版、每日节流、失败静默、弹窗防重入。企划星已有的缝:`http: ^1.2.0` 是**直接依赖**(零新增),
`AppMeta.version`('0.1.0',测试钉住与 pubspec 一致)是版本事实,远端是 `github.com/uifj/flutter_agent_harness`。

## 决策（Decision）

**① 版本源 = GitHub Releases latest API,零手工 version.json。**
`GET https://api.github.com/repos/uifj/flutter_agent_harness/releases/latest`（UA 头必带,GitHub API 要求;
Accept vnd.github+json）。`tag_name` 剥掉可选 `v` 前缀后与 `AppMeta.version` 逐段比较。**不造假字段**:
GitHub API 没有 mandatory 强更开关——hunnu 的 mandatory 在自管 version.json 里才有载体;企划星 v1 全部按可选
更新处理,迁自管 manifest 时再启用该位。prerelease/draft 不提示(取 latest 端点天然不含 draft;prerelease 记为
不提示)。**手动检查失败必须说话**(「检查失败」反馈),自动检查失败静默——hunnu 把两者混为"无更新",对手动检查
是撒谎,不抄。

**② 服务与状态分家,各归各层。**
纯词汇(比较器、payload 解析、结果类型)在 `lib/model/update_check.dart`(无 Flutter,可纯单测);有副作用的
`UpdateService` 在 `lib/state/update_service.dart`——`UpdateService.open(Directory support, {http.Client? client})`,
走 **AppScope** 构造器(GitStatusStore/CheckpointStore 同座,`app_scope.dart:57-70` 的既有惯例),client 可注入
供测试。`check({required bool userInitiated})` 一个入口两个语义:自动检查尊重**每日节流**(lastCheckDate 按日比较)
与**跳过的版本**;手动检查(userInitiated)绕过两者——用户点了就要给答案。

**③ 机器内状态 = `<support>/update.json`。**
`{lastCheckDate, skippedVersion}` 两键,tmp+rename 原子写(仓律),损坏按不存在处理。不进 AppSettings(它不是
用户设置,是内部状态;ADR-0022 的假开关律反过来也成立——别给内部状态发设置页门牌)。

**④ UI = 一枚对话框原语 + 两处接线。**
`lib/ui/primitives/update_dialog.dart`:有更新 → 对话框(「当前 x → 最新 y」+ **[跳过这个版本]**(记 skippedVersion
后关闭) + **[前往下载]**(launchUrl release 的 html_url,回落 releasesUrl));手动无更新 → `showFeedback`
「已是最新版本」;手动失败 → showFeedback「检查失败」。启动自动检查挂 `main` 的 postFrame(与 tray/hotkeys
同一道缝),节流内静默。菜单 `helpReleases` 的 onTap 从 `onOpenLink(releasesUrl)` 改为 `onCheckUpdate` 回调
(main 注入)——releases 网页没有丢,它活在「前往下载」里,不违反"同一动作两扇门会各自腐烂"。

**⑤ http client = package:http(直接依赖 ^1.2.0,零新增)。**
不引 dio(hunnu 评估 §3:其拦截器带着自知的 Content-Type 覆盖缺陷,抄服务不抄坑)。

## 后果（Consequences）

- **正面**: 「发现新版本」从死门变真门;出包(tag → build.yml → GitHub Release)后用户端可感知;六件套齐活。
- **负面/风险**: GitHub API 未认证限流 60 次/时/IP——日节流使人均 1 次/日,充裕;私有仓阶段 releases 为空,
  latest 404 → 按失败静默/「检查失败」——**这是诚实态**(确实没有可更新物),不是假门。
- **中性**: `UpdateCheckResult.error` 与 hunnu 的合并语义不同(手动失败要说话);AppScope 多一个打开的 store;
  版本号进位方案(X.Y.Z+YYYYMMDD,VERSION_PLAN 形态)不在本 ADR——发布时另议。

## 验证（Verification）

- `test/update_check_test.dart`(model 纯函数):比较器等/补丁/次/主版本、tag 剥 v、payload 解析、异常 payload。
- `test/update_service_test.dart`(service + 临时目录):跳过版本两档(userInitiated 绕过)、日节流、失败→error、
  update.json 损坏=不存在、tmp+rename 无残留。
- `test/app_frame_test.dart` 菜单守卫改写:helpReleases 触发的是检查回调而非开链接。
- 四道门禁同口径。

## 关联（Links）

- 代码: `lib/model/app_meta.dart`(版本事实与 releasesUrl)、`lib/state/app_scope.dart:57-70`(store 座位)、
  `lib/ui/app_frame.dart:767-771`(菜单现状)、`lib/main.dart:445-478`(接线点)
- 关联 ADR: ADR-0045(生产化总纲——本 ADR 是其 PA–PG 的续格)、ADR-0072(帮助组菜单——死门的出处)、
  ADR-0078(反馈条唯一入口——「已是最新/检查失败」走它)
- 上游研究: `docs/hunnu-app-osos-vs-planstar-2026-10.md` §1.1(hunnu `lib/core/update/update_service.dart:53-256,262-330,420-521`)
