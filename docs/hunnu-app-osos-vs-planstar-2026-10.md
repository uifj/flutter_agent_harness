# 对标技术文档:hunnu_app_osos 与企划星横向对比与移植评估

> 取证对象:`/Users/uifj/Workspace/Hunnu/giteerepo/hunnu_app_osos`(湖南师范大学官方移动端,Flutter,
> pubspec `3.0.0+20261001`,本地只读副本未入库)。规模实测:**主壳 lib 169 文件/~37.9k 行**,
> 另有 **7 个本地包**(hunnu_common 85 文件/21.8k 行、hunnu_webview 37 文件/10.9k 行、hunnu_auth 19 文件/2.1k 行、
> hunnu_items、hunnu_todo、vendored TUIKit_Flutter 与 flutter_inappwebview_patched)。
> 技术栈:Clean Architecture + Feature-First + BLoC + Repository + Provider DI,dio/intl(gen_l10n)。
> **测试面弱**:test + integration_test 共 10 个文件(企划星 102 棵)——它的强项在**工程化、发布与运营**,不在测试。
>
> 本文所有条目带 `path:line`(相对该副本根)。**两仓同源的工作流 DNA**(AGENTS.md + ponytail + trae rules +
> ADR 纪律)使借鉴摩擦极低:它的守卫脚本与企划星的 guard 惯例同一血统(baseline 递减史 + 已知盲区自述 + self-test)。

## 0. 一句话总评

一个**真实上线运营**的校园超级 App:单点深度不如 kelivo/anytype 的编辑器内核,但**发布运营链路(应用内更新、版本治理、
文案基线看护、崩溃符号化、CI 分档)是三个参考仓里最完整的**——恰好是企划星生产化总纲(ADR-0045)还没长出的那一层。

## 1. 采纳(设计级;动手前按规立 ADR)

### 1.1 应用内更新检查 = UpdateService 的完整形态 ⭐ 最高迁移价值

`lib/core/update/update_service.dart`(521 行)是一个把"更新检查"这件小事做全了的范本:

- **远端版本源**:静态 `version.json`(`:53-61` fetchRemoteVersion)——不需要后端,对象存储/静态托管即可;
  按平台分选(`:106-110` `_selectByPlatform`),payload 带 **mandatory 强更开关**(`version_model.dart`)。
- **比较器**:语义化版本逐段比较,相等再比构建号(`:96-102` compare/_compareSemver/_compareBuild)——不引包,30 行手写。
- **用户尊重三件套**:「跳过这个版本」记忆(`:141-152` + checkForUpdate 内 `:196-207`——非强更时跳过的版本不再提示)、
  每日检查节流(`:104-124` hasCheckedToday)、可选更新走轻提示(`:477-497` showUpdatePrompt 的 SnackBar+action)。
- **失败静默降级**:远端拉取失败一律按"无更新"返回(`:225-234` catch 分支)——检查更新永远不能变成可用性故障。
- **弹窗防重入**:`_isShowingDialog` 布尔(`:45-47,263`);强更弹窗 barrierDismissible + 仅「前往升级」一个动作(`:262-330`)。
- **跳转**:jumpToStore 走 `launchUrl(externalApplication)`(`:479-484` 附近),iOS App Store/华为市场双源。

**对照企划星**:ADR-0072 的帮助组已有「发现新版本」菜单入口,背后是空壳;ADR-0045 生产化总纲 PA–PG 未含更新检查。
桌面适配很小:jumpToStore 的目标从应用市场换成**下载页/产物 URL**(企划星有 build.yml 三平台出包产物),
`package_info_plus` 换成读取 `AppSettings` 的版本事实(ADR-0045 PD 已处置三格)。**建议立 ARC 类 ADR**
(挂在 ADR-0045 旗下),骨架照抄六件套:version.json 源 + 比较 + 跳过本版 + mandatory + 节流 + 失败静默。

### 1.2 硬编码文案的基线看护 = check_hardcoded_strings.sh 的方法论

`tool/check_hardcoded_strings.sh`:扫描用户可见 UI 文案中的中文硬编码,**基线只许降不许升**(`BASELINE=74`,
头部注释完整记录 477→465→414→270→202→200→99→80→74 的递减史与每批的 ADR 号)、`--ci` 超基线退出码 1、
**`--self-test` 防 PATTERN 静默失效**、且头部自述**已知看护盲区**(「PATTERN 只认同行 UI 关键字后紧跟引号的形态,
ADR-0052 的 27 处里只有 19 处落在计数内」)——这种对自家守卫局限的诚实,和企划星 `tap_affordance_test` 按文件计数的
自律同源。

**对照企划星**:ADR-0078 的守卫管「代码用的键必须入字典」,但**管不到「文案压根没进字典」**——本轮企划 UI 裸串扫描
是我手工 grep 的一次性行为。适配点:企划星是自研键值 i18n(非 arb),扫描器可简化(扫 `Text('` 后跟 CJK 的形态),
基线从本轮实测值起步。**建议立 TST 类 ADR**(与 ADR-0078 同族)。

### 1.3 AppLogger 的三条生产策略(借策略,不借代码)

`packages/hunnu_common/lib/logging/logging_service.dart:27-60` 的三段注释各记录一个真实生产教训:

- **只降噪、不封口**(`:37-42`):生产关掉 verbose 日志时只过滤 WARNING 以下——若直接 return,线上连 SEVERE 都
  不落盘,「线上问题将完全无法诊断」。
- **防递归**(`:49-52`):控制台输出直接用 print,避免 onRecord 回调内再触发 log record → 无限递归卡死主线程。
- **格式化异常兜底**(`:44-47`):格式化挂了回退最简输出,格式化错误不许杀日志管道。

外加多 sink 架构(控制台/文件/扩展 sink,`logging` 包 root.onRecord 分发)与 `PerformanceMonitor.trace()`
(`performance_monitor.dart:1-36`,起停计时+失败记 severe 后 rethrow)。

**对照企划星**:崩溃归档(ADR-0056/PC)已有兜底落盘,但**没有统一的分级日志面**——`lib/infra/log.dart` 只服务编辑器,
散落的 debugPrint 不入档案。直接引 `logging` 包需 DEP ADR;**策略层(三条防御 + sink 分层)值得在企划星立
「日志统一」ADR 时整段引用**。

## 2. 参考(按需取形,不动手)

| 项 | 证据 | 对企划星的用法 |
| --- | --- | --- |
| CI 分档:push/PR → ci,tag → release+产物 | `CI-CD.md:5-15`(flutter-ci.yml / flutter-release.yml 双档 + Runner 部署 runbook) | 企划星 `build.yml` 已是 workflow_dispatch;可参考补 **tag `v*` 触发**的 release 档,产物挂 GitHub Release |
| 版本方案 `X.Y.Z+YYYYMMDD` + 三平台版本源清单 | `VERSION_PLAN.md:3-25`(gradle/Info.plist/app.json5 逐处列名) | 企划星版本事实已由 ADR-0045 PD 处置;日期构建号在出包多平台时可参考 |
| 崩溃符号化产物入库 | `debug_info/`(app.android-arm64.symbols 等) | 企划星崩溃归档(ADR-0056/PC)记的是 Dart 侧;若出原生崩溃,符号化产物随 tag 归档是纵深参考 |
| 性能走查方法论 | `PERFORMANCE_OPTIMIZATION.md:1-40`(63.8ms 布局瓶颈 → RepaintBoundary/懒加载/监控器,配 `LayoutPerformanceMonitor`) | 手法通用;企划星的大树/编辑器面做性能走查时照此形(先量化、再隔离重绘、再懒加载) |
| auth 的 repository/status-stream 分层 | `packages/hunnu_auth/lib/src/repositories/authentication_repository.dart:22-50`(AuthenticationStatus 流 + repository 封 sources) | 与企划星 AuthSession(ADR-0045 PE)同构;无新增, 仅确认分层方向一致 |
| 上游补丁 fork 的命名惯例 | `packages/flutter_inappwebview_patched/`(目录名即声明"这是打过补丁的上游") | 企划星 vendored 先例(board_panel、flutter-shadcn-ui)可借鉴此命名纪律:补丁 fork 一律 `_patched` 后缀,一眼可辨 |

## 3. 不迁(红线/不适用,防止未来误判)

| 项 | 理由 |
| --- | --- |
| **BLoC 全家** | 企划星状态管理是 riverpod(ADR-0002,修订在案);换状态管理是重架构,无收益 |
| **gen_l10n/intl/arb** | 企划星 i18n 自研是**刻意决策**(AGENTS §1「刻意不存在的机制」+ 已移除 7 skills 清单),且 ADR-0078 刚按自研语义加固守卫。1.2 的**方法论**可移植,arb 工具链本身不迁 |
| **dio 网络层** | 企划星裸 HTTP 面极小(models_endpoint/genkit provider 承担协议);dio 是新依赖(DEP ADR 门槛),收益低。其拦截器里还留着自知的 Content-Type 覆盖缺陷(`network_interceptor.dart:36-38` 的 todo)——抄的时候连坑一起抄 |
| **腾讯 IM / 小程序 / 音频播放** | 无对应产品面 |
| **storage_service** | `packages/hunnu_common/lib/storage/storage_service.dart` **整文件被注释停用**(1-30 全为注释)——死代码示范;企划星密钥已走 keychain(SecureSecretStore) |
| **installers/dmg_creator** | `config.json` 是**腾讯演示残留**(签名身份/产物路径都是 Tencent Cloud Chat)——非生产物;仅证明 macOS dmg 出包有现成工具形状(create-dmg + config)可抄 |

## 4. 红线检查表(对照企划星 §7)

- 拉它的**代码**入库 = 引依赖/引包,一律先立 DEP/ARC ADR(企划星红线);本文建议的全部是**设计移植**,零代码照抄。
- 它的 AGENTS/ponytail/trae 规则与本仓同源——**规则文件互抄无意义**,两边各自演进。
- 其 README 版本徽章(2.6.4)与 pubspec(3.0.0)**已经漂移**——企划星 ADR-0045 PD 的"版本事实三格同源"是对的,别学它的双处维护。

## 5. 执行顺序建议(若拍板)

1. **更新检查**(1.1)——挂 ADR-0045 旗下立 ARC ADR;version.json 放静态托管;「发现新版本」菜单(ADR-0072)接上真服务;每日常检 + 跳过本版 + 失败静默三件全要。
2. **硬编码文案基线**(1.2)——TST ADR;基线取本轮实测,只降不升;与 ADR-0078 的 used-keys 守卫互补成"键→字典、文案→键"双向闭环。
3. **日志统一**(1.3)——待企划星出现第二个需要分级落盘的面时再立 ADR,届时三条策略整段引用。

## 6. 与其他评估的交叉对照

- **kelivo 评估**给的 B/C 组缺口(定时任务、诊断日志、FTS)在 hunnu 这边只有**诊断日志**有新参考(1.3);其余 hunnu 无对应物。
- **zcode 评估**的生产化差距清单里,「版本事实、崩溃留痕、重置入口」企划星已处置;**「应用内更新」这一格由 hunnu 补上了唯一参考**(1.1)。
- anytype 清本 §17 式的"看起来有其实没有":hunnu 的 `RefactorCode.md` 实为 .md 后缀的 Dart 文件、`hunnu_webview/README.md` 是未改的 flutter create 模板——**文档面不可信,以代码为准**。
