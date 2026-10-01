# ADR-0042: 备份里的条目名不许走出它自己的目录

- 分类: SEC
- 优先级: P1
- 状态: ACCEPTED（2026-10-02，ADR-0039 收尾时发现：`sessions.json` 开始经这份备份往返，restore 侧的写入路径第一次变成"别的东西也要靠它"）

## 背景

`BackupService.restoreBackup` 把一个 zip 里的每个条目直接拼到应用支持目录下写出去：

```dart
final outPath = p.join(support.path, file.name);   // lib/state/backup_service.dart:104
final outFile = File(outPath);
await outFile.parent.create(recursive: true);
await outFile.writeAsBytes(file.content as List<int>);
```

`file.name` 完全来自那个归档文件，而**这个文件是用户在文件选择框里挑的**（`lib/ui/settings/model_settings.dart:1333-1343`：
`FilePicker.platform.pickFiles(allowedExtensions: ['zip'])`）。zip 里的条目名可以是
`../../../../.ssh/authorized_keys`，`p.normalize` 之前它就长这样、之后就走到支持目录外面去了——这就是
OWASP 意义上的 **Zip Slip**。写侧（`createBackup:59-67`）只会产出 `sessions/…`、`workbench/…` 这类相对名，
所以这道门过去只被自家产物经过；一旦备份来自别处（同事发的、网盘下载的、旧机器拷的），它就是一个任意路径写盘。

三条让它值得现在修而不是挂着：① 它不是"恢复失败"，是**在用户自己的目录树上写别人的字节**，失败模式没有回头的余地；
② ADR-0039 之后这份备份还要负责会话的归属、置顶与墓碑（`<support>/sessions/sessions.json`），
它的可信度已经变成产品功能的一部分；③ 修它是一枚纯函数加一次预检，不动备份格式，旧备份照样能读。

## 决策

1. **"这个名字落到哪儿"抽成一枚纯函数**：`resolveBackupEntry(supportPath, name)`（`lib/state/backup_service.dart` 顶层）——
   `p.normalize(p.join(supportPath, name))`，落在支持目录内就返回该路径，落在外面返回 `null`。
   纯函数是因为 `getApplicationSupportDirectory()` 在 widget/单元测试里根本拿不到，
   写在这枚函数旁边的检查是唯一跑得起来的证明方式（同 `decideGate`、`composeWindowTitle` 的先例）。
2. **先全量验名，再动手写。** `restoreBackup` 在写第一个字节之前遍历一遍所有条目，任何一枚 `resolveBackupEntry` 返回
   `null` 就 `throw FileSystemException('backup-escapes-its-folder', name)`，整个恢复不发生。
   逐条跳过是错的：一半文件被换掉、一半没换，用户看不出来，也回不去。
3. **调用方的说法不改。** `model_settings.dart` 那圈 `catch` 已经把异常变成一条 destructive 提示，
   所以这一改不需要新文案，也不需要新的 UI 面。

## 后果

- 恶意或畸形备份的后果从"任意路径写盘"变成"一次都写不下去，并告诉用户哪个名字不对"。
- 自家备份的往返行为一字不变：写侧产出的名字本来就都在支持目录里。
- 守卫：`test/backup_paths_test.dart`（纯函数四格：普通名、嵌套目录、`..` 逃出、深层 `../` 拼回内部）
  加 `restoreBackup` 那条"预检失败时一个字节都不写"——后者需要能注入 support 目录，本轮不假造，
  留给"预检顺序"这条本身（先遍历后写）由代码形状保证，并被纯函数那四格覆盖到判定部分。

## 明确不做

- **不改备份格式、不加签名/清单**（比如附一份 SHA-256 逐文件校验）。那是"这备份是谁做的"的另一件事，
  要做得连着 `settings.json` 里的 API key 一起考虑（备份现在明文带着它），先立 ADR 再说。
- **不在本次处理 zip bomb**（解压后体积无上限）。它会让恢复变慢而不是越权，属于另一条观察。
