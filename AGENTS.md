# WriterAssistant - Agent Guide

## 项目概览

WriterAssistant 是一款**面向中文网文作者的 AI 辅助写作桌面应用**，使用 Flutter 构建，目标平台为 Windows（同时保留了 linux/macos/web 工程骨架）。

- **仓库**: `https://github.com/KongMingT/WriteAssistant.git`
- **框架**: Flutter 3.27 / Dart 3.6
- **状态管理**: Riverpod 2.x
- **数据库**: drift (SQLite ORM, 代码生成)，11 张表 / 9 个 DAO，schemaVersion=4
- **AI 接入**: Dio (HTTP)，支持 DeepSeek/通义千问/OpenAI/Moonshot 四家供应商，端点/模型可自定义
- **构建**: `flutter build windows` (需 VS2022 C++ 桌面工作负载)
- **构建产物**: `build\windows\x64\runner\Debug\writer_assistant.exe`

---

## 目录结构

```
lib/
├── main.dart                          # 入口 (预加载主题后 runApp)
├── app.dart                           # MaterialApp 根组件 (首页=BookSelectionScreen)
├── core/
│   ├── ai/
│   │   ├── ai_client.dart             # Dio 客户端 (流式SSE + 自动重试拦截器 + 自定义端点/模型)
│   │   ├── models/ai_model_config.dart # AiProvider 枚举 + API Key 安全存储 + Provider
│   │   └── prompts/prompts.dart       # 10 套提示词模板
│   ├── database/
│   │   ├── database.dart              # AppDatabase 定义 (schemaVersion=4)
│   │   ├── database.g.dart            # Drift 生成代码
│   │   ├── providers.dart             # 9 个 DAO 的 Riverpod Provider
│   │   ├── tables/ (11张表)
│   │   │   ├── books.dart             # 书籍 (autor/status/genre/description/cover/wordCount)
│   │   │   ├── volumes.dart           # 卷 (关联 book)
│   │   │   ├── chapters.dart          # 章节 (content 无长度限制, 关联 volume)
│   │   │   ├── characters.dart        # 角色 (关联 book)
│   │   │   ├── character_relations.dart # 角色关系 (无UI使用)
│   │   │   ├── outline_nodes.dart     # 大纲节点 (bookId/chapterId/parentId/type/status)
│   │   │   ├── plot_lines.dart        # 剧情线 (无UI使用)
│   │   │   ├── plot_nodes.dart        # 剧情节点 (无UI使用)
│   │   │   ├── writing_sessions.dart  # 写作时段 (编辑器会话边界自动写入)
│   │   │   ├── ai_chat_messages.dart  # AI 对话消息 (持久化, 重启不丢)
│   │   │   └── chapter_snapshots.dart # 章节版本快照 (autoIncrement seq 主键)
│   │   └── daos/ (9个DAO)
│   │       ├── book_dao.dart          # 含 recalculateBookWordCount (SQL SUM) + 事务级联删除
│   │       ├── volume_dao.dart
│   │       ├── chapter_dao.dart
│   │       ├── character_dao.dart     # 含角色关系 CRUD
│   │       ├── outline_dao.dart       # 书籍级/章级大纲 + 批量插入
│   │       ├── plot_dao.dart          # 剧情线/节点 (未被调用)
│   │       ├── session_dao.dart       # 写作会话 (编辑器写入 + 日/周/期间统计查询)
│   │       ├── ai_chat_dao.dart       # 对话消息 CRUD (含 ChatMessage 模型定义)
│   │       └── snapshot_dao.dart      # 章节快照 创建/查询/按章删除
│   ├── services/
│   │   ├── txt_import_service.dart    # TXT 导入 (编码检测 + 高级章节拆分, 标题正文分离)
│   │   ├── txt_export_service.dart    # 导出 TXT/Markdown/EPUB (单章/整书) + TXT 整书合并
│   │   └── chapter_compress_service.dart # 章节压缩 → 摘要回写 outline_nodes
│   └── utils/
│       └── id_generator.dart          # UUID v4 生成器 (使用 uuid 包)
├── features/
│   ├── book_selection/
│   │   └── book_selection_screen.dart # 首页：书籍卡片网格 + 新建/导入/长按编辑/删除
│   ├── workspace/
│   │   ├── workspace_screen.dart      # 三栏布局 + 全局快捷键 + 沉浸模式 + 导出菜单 + AppBar
│   │   ├── sidebar/chapter_tree.dart  # 卷→章节树 (右键菜单 + 拖拽排序)
│   │   ├── editor/chapter_editor.dart # 编辑器 (工具栏+标题+章纲+正文+自动保存+撤销重做+历史版本)
│   │   ├── editor/search_dialog.dart  # Ctrl+F 全文搜索/替换
│   │   ├── ai_panel/ai_panel.dart     # AI 对话面板 (流式+上下文选择+大纲快捷操作+持久化)
│   │   └── models/selection_state.dart # 选中状态 + 信号 + AI 上下文 Provider + ChatMessage 状态
│   ├── outline/
│   │   ├── outline_screen.dart        # 书籍大纲管理页 (三栏: 大纲树|编辑器|AI面板)
│   │   └── outline_panel.dart         # 编辑器内嵌单章章纲面板
│   ├── character/
│   │   ├── character_sheet.dart       # 角色管理底部弹窗 (含编辑对话框 + 悬浮信息提示)
│   │   └── character_list_screen.dart # (遗留) 旧版独立角色页，AI 面板"人物"快捷操作仍引用
│   ├── settings/settings_screen.dart  # AI 供应商配置 + 自定义端点/模型 + 上下文选章上限 + 连接测试
│   └── book_analysis/book_analysis_screen.dart # 拆书分析 (导入 TXT → AI 分析 → 导入为书籍)
└── shared/
    ├── themes/theme_provider.dart     # 主题/字号/字体 Provider (持久化)
    └── widgets/
        ├── status_bar.dart            # 底部状态栏 (字数/速度/时长/已选章/每日目标/主题切换)
        ├── daily_goal_provider.dart   # 每日字数目标 Provider (secure storage 持久化)
        ├── writing_stats_dialog.dart  # 写作统计弹窗 (今日/本周/期间 + 趋势图)
        ├── undo_stack.dart            # 手动撤销栈 (TextEditingValue 快照)
        └── app_logo.dart              # 自定义 W 字母 Logo (CustomPainter)
```

`tools/` 目录包含图标生成脚本（`generate_icon.dart`、`make_icon.dart`，非应用业务代码，可忽略 lint）。

---

## 当前功能清单

### 书籍选择首页
- 启动后显示书籍卡片网格（渐变封面 + 书名 + 字数），卡片随窗口宽度自适应列数
- 点击卡片进入工作区，长按或右上角菜单可编辑书名/删除
- 右上角导入 TXT、新建书籍按钮；空状态内联新建/导入
- 新建书籍自动创建第一卷/第一章，导入/新建后自动跳转工作区

### 编辑器
- 三栏可拖拽布局（目录 | 编辑器 | AI 面板），面板可折叠
- **沉浸模式 (Ctrl+Shift+M)**：一键隐藏侧栏/状态栏全屏写作，AppBar 图标切换
- 工具栏：4 种中文字体（宋体/楷体/黑体/微软雅黑）、字号 12-32px、增加/减少缩进、自动排版全文、显示/隐藏章纲、**历史版本**
- 自动保存：正文 3 秒防抖，标题 500ms 防抖；`Ctrl+S` 强制即时保存；离开编辑器立即保存
- 保存后通过 `bookDao.recalculateBookWordCount()` (SQL SUM) 同步更新 `books.wordCount`；`_saveImmediately` 内容未变化时跳过（避免空快照/空会话记录）
- Tab 插入全角空格首行缩进，Enter 自动继承前导缩进（拦截键事件手动插入，无时序问题），Shift+Enter 跳过缩进
- 增/减缩进支持单段落与多行选中；自动排版为全文所有行补首行缩进
- `Ctrl+Z` / `Ctrl+Y` 撤销重做（`UndoStack` 手动快照，每 300ms 记录一次，Enter/Tab 自定义操作均可撤销）
- 单章 >200000 字符时 SnackBar 提示建议拆分（大章节性能保护）

### 全文搜索/替换 (Ctrl+F)
- `SearchDialog` 跨卷/章搜索标题和正文，显示匹配上下文（±20 字）
- 支持「替换一项」和「全部替换」（无正则，区分大小写）
- 点击结果跳转到对应章节并关闭对话框

### 书籍管理
- 书籍 → 卷 → 章节三级结构，侧边栏只显示当前书的卷/章节
- 侧边栏右键菜单：新建卷/章、重命名、删除（带确认对话框；删卷手动级联删章）
- **拖拽排序**：按住拖拽可调整同级卷/章节顺序（`_onDragEnd` 换位 + `reorder` DAO 更新 sortOrder）
- 新建时自动命名（"第一卷"/"第一章"），新建章节按当前总数递增
- **导入 TXT**：自动检测编码 UTF-8/GBK；章节拆分支持 `第[X]章/回/节/部`、`序章/序言`、`尾声/后记/结局`、`Chapter N`、`第N话`、`Vol.*/卷*` 等；标题与正文分离（`ImportedChapter{title, content}`），原文标题不再残留正文
- **删除书籍级联**：`deleteBook` 事务内依次删除 卷→章节→章级大纲→书籍级大纲→角色关系→角色→写作会话
- **导出多格式**：先选范围（当前章/整书）再选格式 TXT / Markdown / EPUB；Ctrl+E 打开导出菜单；EPUB 含 title/metadata/mimetype(store) 标准结构

### 书籍大纲系统
- 工作区 AppBar「大纲」按钮进入 `OutlineScreen` 三栏页面（大纲树 | 节点编辑器 | AI 面板）
- `outline_nodes` 支持书籍级（bookId，根节点 `type=book_root`）+ 章级（chapterId）两级数据
- 节点类型：卷→章→节→剧情点，右键菜单可添加子节点/同级/删除（递归）
- 中间编辑区：标题 500ms 防抖、内容 3s 防抖实时保存；显示类型/字数/草稿·定稿状态；章节点可下拉关联章节
- 底部状态栏：节点总数 / 已定稿数 / 进度百分比；展开全部/折叠全部
- **AI 生成大纲可导入**：`_tryImportOutline` 解析 AI 返回的 JSON 大纲 → 递归生成节点 → 确认对话框 → 批量插入 `outline_nodes`
- **导出大纲**：节点树序列化为 Markdown 写入文件

### 新书规划 + 章节压缩
- AI 面板「新书规划」：表单（概念/类型/角色/世界观/体量）→ `AiPrompts.bookPlanning()` 生成 5 维度 Markdown 规划
- 已有章节被选中时：自动调 `ChapterCompressService` 分批压缩（每批 ≤15000 字符）→ 逐章 ~300 字摘要 → 回写 `outline_nodes` (`type=chapter_summary`, `status=final`) → 摘要自动填入表单只读区

### AI 对话面板
- 流式 SSE 打字机效果 + 自动重试（超时/500 错误重试 2 次，指数退避）
- 10 种快捷操作：新书规划、细纲扩写、起名、卡文助手、拆书、人物、生成大纲、扩写节点、润色节点、生成细纲（后 4 项仅在大纲页选中节点后显示）
- **上下文选择**：面板内可折叠的卷→章节多选树，双击阈值（设置页可选 5/10 章上限 + 固定 20000 字符）；`_buildContext` 统一组装选中章节 + 当前章节前 2000 字 + 角色列表前 500 字
- **对话持久化**：`aiChatMessagesProvider`（`StateNotifierProvider<AiChatController, List<ChatMessage>>`）启动时从库加载，助手消息落盘 `ai_chat_messages`（重启恢复，跨面板生命周期）
- 一键复制 AI 回复、清空对话、AI 面板内快捷进设置
- 面板文字与输入框复用编辑器字体设置

### 角色管理
- 工作区 AppBar「人物」→ 底部弹窗（不离开编辑区），标题带当前书名
- 角色卡片列表（类型标签：主角/反派/配角），CRUD 弹窗：姓名/类型/性别/年龄/性格/背景/外貌/备注
- **悬浮提示**：卡片悬停展示完整信息（性别/年龄/性格/背景/外貌/备注），无需进弹窗
- 自动关联当前书籍

### 拆书分析
- 导入外部 TXT → AI 分析（人物/关系/节奏/技巧）→ 结果可复制、可导入为书籍

### 写作追踪
- 底部状态栏实时显示：字数、码字速度（字/时）、本次写作时长、AI 已选 N 章
- 一键切换深色/浅色主题（持久化）
- **写作落库**：保存/切换章节/退出时经 `session_dao` 写入 `writing_sessions`（`_startSession`/`_endSession`，保证内容切换前结算）
- **统计弹窗**（点击状态栏字数/速度区）：今日 / 本周 / 期间字数 + 每日趋势图
- **每日目标**：状态栏显示进度条（今日/目标，达成金色高亮）；点击设置目标（预设 2000/3000/5000/10000 或自定义，持久化 `daily_goal`）

### 快捷键
| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 强制保存当前章节 |
| `Ctrl+N` | 新建章节 |
| `Ctrl+E` | 导出当前章节（打开范围+格式选择菜单） |
| `Ctrl+F` | 全文搜索/替换 |
| `Ctrl+Z` / `Ctrl+Y` | 撤销 / 重做（编辑器内） |
| `Ctrl+Shift+M` | 沉浸模式 开/关 |

---

## 关键技术决策

### 状态管理: Riverpod
- `StateProvider` — 简单状态（选中章节/书籍、写作状态、信号、AI 上下文选择、每日目标）
- `FutureProvider` — 异步配置（AI 配置）
- `StateNotifierProvider` — 可变设置（主题模式、字号、字体族，均持久化到 secure storage）+ AI 对话控制器（`AiChatController`）+ 每日目标（`DailyGoalNotifier`）
- `Provider` — 依赖注入（数据库、9 个 DAO）

### 信号驱动跨组件通信
使用 `StateProvider<int>` 作为信号：
- `treeRefreshProvider` — 目录树刷新
- `forceSaveProvider` — 强制保存（Ctrl+S 触发）
- `newChapterRequestProvider` — 全局新建章节（chapter_tree 监听）
- `outlineTreeRefreshProvider` — 大纲树刷新

### 页面路由
- `BookSelectionScreen` (首页) → `Navigator.push` → `WorkspaceScreen(bookId)`
- 工作区 AppBar 返回按钮 → `Navigator.pop` → 回到书籍选择页（返回后刷新列表）
- 大纲页 / 拆书 / 设置 / 角色弹窗均为独立路由或弹窗

### 数据库
- drift ORM，11 张表，9 个 DAO，`schemaVersion=4`
- 数据库文件路径：`getApplicationDocumentsDirectory()/writer_assistant.db`
- 使用 String UUID 作为主键（`uuid` 包 v4）；`chapter_snapshots` 例外，用 `autoIncrement` 的 `seq` 主键保证严格有序
- `onUpgrade`：v1→v2（12 列新增）、v2→v3（outline_nodes 新增 bookId/status）、v3→v4（新增 ai_chat_messages / chapter_snapshots 两表）。**改表时必须同步更新 `schemaVersion` 和 `onUpgrade`**
- `deleteBook` 已实现事务级联删除（见书籍管理）；其余外键默认无级联

---

## 待完善 & 注意事项

### ✅ 已解决（原 A-H 批次后）
- 沉浸模式（`Ctrl+Shift+M`）、拖拽排序、写作落库+趋势、导出多格式、角色悬浮提示、AI 对话持久化、每日目标、版本快照、大章节提示、导入格式增强、书籍删除级联、自定义端点/模型、lint 清理

### ⚠️ 剩余已知问题
1. **无 UI 的死数据表** — `plot_lines`/`plot_nodes`（剧情线）、`character_relations`（角色关系）已建表但无 UI/调用方
2. **死代码/未用模板** — `AiPrompts.writerBlock`/`expandOutline`/`generateChapterOutline` 未被调用（快捷操作用内联文本）
3. 🔮 **远期** — 多语言 / 日志 / 自动更新 / 云同步 / AI 对话 token 上限自定义 / 章节批量处理

### ✅ 已修复（代码实现与文档不一致处）
- **AI 大纲导入自动创建根节点** — `ai_panel.dart:596-611` 已实现首次导入时自动创建 `book_root`，不再静默失败
- **`getOutlineByBook` 正确过滤 `chapterId=''`** — `outline_dao.dart:26` 已有 `n.chapterId.equals('')` 过滤，并新增测试验证 `chapter_summary` 类型节点被正确排除

---

## 已实现专题

### 书籍大纲系统
- 数据结构见上（`outline_nodes`，书籍级 + 章级两级）
- **关系模型**：`Book(1)→OutlineNode(N, bookId)`，`book_root` 单条自动创建，卷→章→节/剧情点无限嵌套；章级节点用 `chapterId` 关联并由编辑器内嵌面板展示
- `OutlineDao` 关键方法：`getOutlineNodesByChapter` / `getBookRoot` / `getOutlineByBook` / `getOutlineNodesByParent` / `insertOutlineNode` / `insertOutlineNodes`(批量事务) / `updateOutlineNode` / `deleteOutlineNode` / `deleteOutlineByBook`
- AI 大纲导入：`_showGenerateOutlineDialog` → `AiPrompts.generateOutline` → 对话区展示 → `_tryImportOutline` 提取 ```json → 递归 `_jsonToCompanions` → 确认对话框 → 批量插入 → 刷新

### 写作统计（批次E）
- `endSession(id, wordCount, {DateTime? endTime})`；会话边界在 `_loadChapter` 内保证：`_saveImmediately()`(旧章) → `_endSession()`(内容切换前结算) → 加载新章 → `_startSession()`
- `SessionDao` 统计查询：`getWordCountSince`(期间字数) / `getDailyWordCounts`(近 N 天日聚合) / `deleteSessionsByBook`(级联用)
- `writing_stats_dialog.dart` 展示今日/本周/期间 + 趋势；`_saveImmediately` 无变化时跳过写入避免空会话

### 导出多格式（批次F）
- `ExportFormat { txt, markdown, epub }`；`exportChapter`/`exportBook`(有向参数)
- EPUB 用 `archive` 包：mimetype 必须 `ArchiveFile.noCompress` 且排最前，普通文件输入原始字节让 ZipEncoder 自行 deflate，`ZipEncoder().encode` 返回可空 Uint8List

### AI 对话持久化 + 版本快照（批次H1/H2）
- 表 `ai_chat_messages`（bookId/title/reply/createdAt）；`AiChatController.persistNow` 在流结束后落盘，App 启动 `AiChatController` 从库加载
- `chapter_snapshots`（autoIncrement `seq` 主键）：编辑器 `_saveImmediately` 时若内容/标题有变化，先插入旧内容快照再写库；工具栏「历史版本」列出（时间倒序）→ 确认 → 恢复 + 保存；`SnapshotDao.deleteSnapshotsByChapter` 级联删除

### 每日目标 + 角色悬浮（批次H3/H4）
- `dailyGoalProvider`：FlutterSecureStorage key `'daily_goal'`；`_GoalProgress` 组件（今日/目标 + LinearProgressIndicator + 达成金色 🎉）；`_showGoalDialog` 预设/自定义
- 角色卡片 `Tooltip(message: _characterInfo(user))` 悬停展示完整信息

### TXT 导入增强 + 级联删除 + 性能（批次G）
- `splitChapters` 返回 `List<ImportedChapter>`；`_matchHeader` 用"标记 正则 + ['==','--','\x1b',''] 分隔符集"双重判定，避免正文行误判；修正 trim 吞掉分隔符 bug
- `BookDao.deleteBook` 事务级联（卷→章→章级大纲→书籍级大纲→角色关系→角色→会话）
- 编辑器 `_largeChapterThreshold = 200000`，超限 SnackBar 提示拆分

### 自定义端点/模型（批次B）
- `AiModelConfig` 支持 customEndpoint/customModel；`AiClient` 构造时注入，设置页实际生效；API Key 独立密钥安全存储

### 撤销/重做（UndoStack）
- 双栈管理 `TextEditingValue`，去重 + 容量 200，push 清空 redo；Enter/Tab/缩进/自动排版均记录；`_isUndoingRedoing` 防循环；切章 clear

### 全文搜索/替换（SearchDialog）
- 跨卷/章遍历标题与正文；±20 字上下文；300ms 防抖；`_replaceOne`/`_replaceAll`；替换后刷新目录树

### Utf8Decoder 流式类型错误（已修复）
`ai_client.dart:86` 使用 `(response.data.stream as Stream<Uint8List>).cast<List<int>>()` 包装流，配合 `import 'dart:typed_data'`。拆书页走非流式 `chat()`，不受影响。

---

## 已知细节 & 边界

1. **章级大纲（outline_panel）节点不带 bookId**，与书籍级大纲通过 `chapterId` 关联；编辑器内章纲面板展示 `chapterId == 当前章` 的节点
2. **`AiProvider` 默认端点/模型** 仍是 `_getEndpoint`/`_defaultModel` 兜底；自定义端点/模型仅在用户显式配置时覆盖
3. **AI 面板 `_quickAction` 的 'expand'（细纲扩写）与 'writerBlock'（卡文助手）发送的是需用户自行填写的模板文本**，并非自动抓取章纲/正文
4. **`_selectLatestChapter`** 按 sortOrder 取全书最大章节，进入工作区自动定位
5. **字符/字数统计基于 `content.length`**（含标点换行），非中文分词统计
6. **`_saveImmediately` 无变化则跳过**写库/快照/会话结算；但 `recalculateBookWordCount` 仍在相关入口调用
7. **测试**：9 个 DAO + 3 个 Service + widget 共 71 个用例全部通过；测试用 `AppDatabase(executor: NativeDatabase.memory())` 在内存库中运行
8. **EPSILON 注意**：dart fix 已批量把 243 处 const/final 修复；改动应保持 lint 干净（analyze 目标 0 error / 0 warning）

---

## 构建与运行

```bash
# 获取依赖
flutter pub get

# 生成 drift 代码 (改表后需要)
dart run build_runner build --delete-conflicting-outputs

# Windows 调试运行
flutter run -d windows

# Windows 构建
flutter build windows --debug
# 产物: build\windows\x64\runner\Debug\writer_assistant.exe

# 代码分析
flutter analyze

# 运行 DAO + 服务测试
flutter test test/daos/
flutter test test/services/

# 运行全部测试
flutter test
```

**前置条件**: Flutter 3.27+, Dart 3.6+, Visual Studio 2022 (含 C++ 桌面工作负载), Windows 10/11 64-bit

**当前状态**: `flutter analyze` 无 error / 无 warning（仅 tools/ 脚本 2 条 avoid_print info 可忽略）；`flutter test` 71 用例全绿。

---

## Git 组织

- 每完成一个功能批次：`flutter analyze` + `flutter test` 验证通过后提交并推送
- 提交信息风格：`feat:/fix:/chore: 中文描述 (+ 可选的要点列表)`
- 历史批次提交：A 技术债清理(519f5ba) / B 自定义端点(1f31850) / C 沉浸模式(1f31850→08c580a 前 b1f? 见 `git log`) / D 拖拽(1f31850, 08c580a) / E 写作统计(1b67b21) / F 导出(39a0453) / G 导入+级联+性能(294b7b8) / H1+H2 AI持久化+快照(0278c08) / H3+H4 悬浮提示+每日目标(1ca3f5e) / I lint( b571532)

---

## 🎯 开发规划：用户视角的竞品差距与功能增强

> 基于「网文作者/写作爱好者」视角，对比 **笔神/作家助手/起点后台/Notion/Obsidian/Scrivener/秘塔写作猫/Notion AI** 等主流工具，梳理核心差距与优先级。

---

### P0 - 核心刚需（直接影响「能不能用」和「留存」）

| # | 功能 | 竞品参考 | 现状差距 | 实现建议 |
|---|------|----------|----------|----------|
| 1 | **云同步/多端** | 石墨/Notion/作家助手/起点后台 | 仅本地 SQLite，换设备/重装即丢失 | Firebase / Supabase / 自建 WebDAV + 加密同步；冲突合并策略（最后写入胜/手动合并） |
| 2 | **一键投稿/发布** | 起点作家助手/晋江后台/飞卢/笔神 | 无平台对接，导出后需手动复制粘贴 | 实现主流平台 API（起点/晋江/飞卢/塔读/红袖/纵横/书旗/掌阅），章节批量推送、定时发布、状态同步 |
| 3 | **大纲可视化** | Scrivener Corkboard / Obsidian Canvas / XMind / 幕布 | 仅树形列表，无概览、无拖拽调整结构 | 增加「画布模式」：卡片式卷/章/节拖拽、连线、颜色标记、缩放/平移；支持思维导图/时间轴切换 |
| 4 | **素材库/设定集** | Notion 数据库 / Scrivener Research / 世界观笔记 | 仅角色表，无势力/地图/物品/法术/种族/年表 | 新增 `world_entities` 表（type: faction/location/item/race/magic/term/timeline），支持模板、标签、关联图谱 |
| 5 | **AI 深度写作辅助** | 秘塔写作猫 / Notion AI / 通义千问写作 / 笔神 AI | 仅对话+生成大纲，**无续写/润色/扩写/降重/查重/命名/灵感** | 接入流式续写（光标位置补全）、段落润色（风格迁移）、扩写/压缩、敏感词/违规检测、自动起名、灵感卡片 |

---

### P1 - 体验增强（显著提升「好不好用」和「日活」）

| # | 功能 | 竞品参考 | 现状差距 | 实现建议 |
|---|------|----------|----------|----------|
| 6 | **专注/沉浸模式深度** | iA Writer / Ulysses / 专注薄 / Forest | 仅隐藏侧栏，**无打字音效/背景图/白噪音/打字机模式/逐行高亮/夜间护眼** | 增加：打字音效（机械键盘/铅笔/墨水）、自定义背景图/视频、白噪音（雨声/火炉/咖啡厅）、打字机模式（当前行居中）、逐行/逐句高亮、番茄钟内置 |
| 7 | **写作目标与习惯系统** | 番茄ToDo / Forest / 习惯工厂 / NaNoWriMo | 仅每日目标，**无连续签到/周目标/奖励机制/写作热力图/连续天数/勋章** | GitHub Contributions 风格热力图、连续写作天数、里程碑勋章（1万/10万/100万字）、周/月目标、导出年度报告 |
| 8 | **高级统计分析** | Scrivener 统计 / 笔神数据 / 起点后台数据 | 基础字数/速度，**无词频/高频词/节奏曲线/对话占比/场景分布/人物出场统计** | 文本分析：中文分词、词频云、对话/描写/心理比例、章节节奏图、角色出场时间线、敏感词高亮 |
| 9 | **版本控制与对比** | Git / Google Docs 历史 / Notion 页面历史 | 快照仅列表，**无 Diff 对比/分支/命名版本/回滚到任意点/协作合并** | 引入 diff-match-patch，支持：两版本并排 Diff、语义化版本标签、分支实验性写作、一键回滚 |
| 10 | **导出格式完善** | Scrivener / 笔神 / 起点后台 | 仅 TXT/MD/EPUB，**无 PDF/Docx/起点专用格式/印刷版排版/多版本导出** | 增加：PDF（自定义页眉页脚/目录/封面）、Docx（保留格式）、平台专用格式、批量导出分卷、印刷排版预览 |

---

### P2 - 差异化/护城河（形成「离不开」的粘性）

| # | 功能 | 竞品参考 | 现状差距 | 实现建议 |
|---|------|----------|----------|----------|
| 11 | **协作与反馈** | 石墨/飞书/Notion/Google Docs | 单机单人，**无编辑/责编/读者协作/评论/建议模式/共享链接** | 邀请编辑/责编留痕评论、生成只读分享链接（含密码/过期时间）、读者弹幕式反馈导入 |
| 12 | **时间轴/年表/因果链** | Aeon Timeline / Scrivener / 奥比岛年表 | 无时间维度管理，**无法查事件先后/人物年龄/因果一致性** | 基于 `outline_nodes` + 新增 `timeline_events`，可视化时间轴、自动校验年龄/事件矛盾、导出年表 |
| 13 | **灵感捕捉/素材箱** | Obsidian Quick Capture / Flomo / 为知笔记 | 无碎片化记录入口，**灵感来不及记、素材散落微信/备忘录** | 全局快捷键/悬浮球快速记录、语音转文字、OCR 图片识别、网页剪藏、标签自动归类 |
| 14 | **智能命名/生成器** | 秘塔起名 / 笔神命名 / 奇妙起名 | 仅 AI 对话起名，**无专用生成器/批量生成/风格筛选/收藏/一键替换** | 独立命名面板：人名/地名/功法/丹药/势力/秘境/装备，按风格/字数/寓意筛选、批量导入替换 |
| 15 | **数据安全与备份** | 1Password / Bitwarden / 自动备份 | 仅本地 DB，**无自动备份/加密导出/防误删/设备指纹绑定** | 定时增量备份（可配置目录/云盘）、AES-256 加密导出、删除保护（回收站 30 天）、设备指纹绑定解锁 |

---

### P3 - 生态扩展（长期护城河）

| # | 功能 | 说明 |
|---|------|------|
| 16 | **插件/脚本系统** | Lua/JS 插件：自定义导出模板、自动化工作流、第三方 AI 接入、平台发布适配器 |
| 17 | **社区/模板市场** | 大纲模板/世界观模板/角色卡模板/提示词模板 分享与订阅 |
| 18 | **多语言** | 英文/日文/繁体界面，面向海外华语作者 |
| 19 | **移动端** | Flutter 原生优势，适配 Android/iOS（触屏优化、手写笔支持、离线同步） |
| 20 | **Web 版** | 浏览器轻量编辑、协作、分享链接打开即用 |

---

### 📋 近期迭代建议（按 ROI 排序）

| 迭代 | 主题 | 核心交付 | 预估工作量 |
|------|------|----------|------------|
| J | **云同步 MVP** | WebDAV/自建同步 + 冲突合并 + 设备管理 | 3-4 周 |
| K | **一键投稿（起点/晋江/飞卢）** | 3 家平台 API 对接 + 章节队列 + 状态同步 | 2-3 周 |
| L | **大纲画布模式** | 卡片拖拽/连线/缩放/切换树形 | 2-3 周 |
| M | **AI 续写/润色/扩写** | 光标补全 + 段落重写 + 风格迁移 + 敏感词检测 | 3-4 周 |
| N | **素材库/设定集** | 实体类型/模板/标签/关联图谱/搜索 | 2-3 周 |
| O | **专注模式深度** | 音效/背景/白噪音/打字机/番茄钟 | 1-2 周 |
| P | **写作热力图/习惯/勋章** | GitHub 风格热力图 + 连续天数 + 里程碑 | 1-2 周 |
| Q | **版本 Diff/分支** | 并排对比 + 语义版本 + 实验分支 | 2-3 周 |
| R | **PDF/Docx/平台格式导出** | 排版引擎 + 模板 + 批量导出 | 2-3 周 |
| S | **时间轴/年表/因果校验** | 可视化时间轴 + 自动矛盾检测 | 2-3 周 |

---

### 🛠 技术债与架构预演（配合上述功能）

| 领域 | 现状 | 目标 |
|------|------|------|
| **数据层** | drift + 本地 SQLite | 抽象 `StorageBackend` 接口，支持 Local / WebDAV / Supabase / Firebase 热插拔 |
| **同步层** | 无 | CRDT / Operational Transform / 简易 LWW + 向量时钟冲突解决 |
| **AI 层** | 单一 `AiClient` | 策略模式：`AiProvider` 插件化，支持本地模型、多模型路由、Prompt 模板市场 |
| **导出层** | 硬编码 TXT/MD/EPUB | 模板引擎 + 渲染器插件，支持用户自定义导出模板 |
| **UI 架构** | 单体 ConsumerWidget | 模块化 Feature + 共享 Kernel，支持懒加载、插件热更 |
| **测试** | 71 单元测试 | + 集成测试（同步/发布/AI流）、黄金文件测试（导出/渲染）、性能基准 |

---

### 📌 决策原则

1. **数据主权优先**：本地优先、端到端加密、用户可导出完整数据
2. **渐进增强**：核心写作流不可破坏，新功能默认关闭/可选
3. **隐私合规**：无埋点上传内容、API Key 仅本地加密存储、遵守平台 API 条款
4. **性能红线**：单章 >200k 字符警告、大纲 >5k 节点虚拟化、启动 <2s、内存 <300MB
5. **开源友好**：核心逻辑 MIT，云同步/发布插件可闭源商业化

---

## 📱 Android 端适配规划

> Flutter 原生支持 Android，但当前代码以 Windows 桌面为主，需针对性适配移动端交互与能力差异。

### ✅ 已就绪（无需改动）
- **依赖兼容**：所有依赖（drift/sqlite3_flutter_libs/path_provider/file_picker/flutter_secure_storage/dio/archive/uuid/intl）均支持 Android
- **数据库路径**：`getApplicationDocumentsDirectory()` 跨平台通用，SQLite 文件直用
- **AI 网络请求**：Dio + SSE 流式在 Android 同桌面表现一致
- **资源文件**：字体/图标/主题通过 `flutter:` assets 配置即可复用

### ⚠️ 需适配项（按优先级）

| # | 模块 | 问题 | 方案 | 工作量 |
|---|------|------|------|--------|
| 1 | **键盘快捷键** | `HardwareKeyboard`/`KeyEvent` 仅桌面/网页有效；移动端无 Ctrl+S/F/E/N/M | AppBar/底部工具栏补充对应图标按钮（保存/搜索/导出/新建章节/沉浸模式）；设置页可配置手势触发 | 低 |
| 2 | **右键菜单/悬浮** | `onSecondaryTapDown`/`MouseRegion` 移动端无效 | 长按替代右键；悬浮提示改为点击展开/底部Sheet；`chapter_tree.dart`/`outline_screen.dart` 需改造 | 中 |
| 3 | **文件选择/导出目录** | `FilePicker.getDirectoryPath()` Android 受限（Scoped Storage） | 改用 `FilePicker.pickFiles()` 选单文件；整书导出改为「保存到下载目录」或分享面板 (`share_plus`) | 中 |
| 4 | **拖拽排序** | `Draggable`/`DragTarget` 桌面鼠标友好，触屏体验差 | 章节/卷排序改为「编辑模式」+ 上下箭头按钮/长按拖拽手柄（`reorderable_list`） | 中 |
| 5 | **三栏布局** | 手机屏幕宽度不足承载 目录+编辑器+AI 面板 | **响应式断点**：<600dp 单栏（底部Tab切换）、600-900dp 双栏（目录/编辑器+AI抽屉）、>900dp 三栏；`LayoutBuilder` + `NavigationRail`/`BottomNavigationBar` | 高 |
| 6 | **沉浸模式** | 全屏隐藏状态栏/导航栏需 Android 原生 API | `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`；配合手势退出 | 低 |
| 7 | **编辑器工具栏** | 当前横向工具栏在窄屏溢出 | 折叠菜单/分组/底部浮动工具栏；字体/字号/缩进改为弹窗选择器 | 中 |
| 8 | **虚拟键盘遮挡** | `windowSoftInputMode=adjustResize` 已配置，但需测试底部状态栏/输入框不被遮挡 | 编辑器底部 padding 动态适配 `MediaQuery.viewInsets.bottom` | 低 |
| 9 | **大章节性能** | 单章 >200k 字符在移动端内存/渲染更敏感 | 虚拟化渲染（`ExtendedTextField`/`flutter_quill`）、分页加载、建议拆分阈值降低到 100k | 中 |
| 10 | **权限声明** | 读写文件/网络/存储需在 `AndroidManifest.xml` 声明 | `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE` (API<29) / `INTERNET` / `ACCESS_NETWORK_STATE` | 低 |

### 🛠 配置清单

```yaml
# pubspec.yaml 新增
dependencies:
  share_plus: ^10.0.0          # Android 分享面板（导出文件）
  permission_handler: ^11.0.0  # 运行时权限申请
  flutter_quill: ^10.0.0       # 可选：替代原生 TextField，更好移动端富文本支持
```

```xml
<!-- android/app/src/main/AndroidManifest.xml 新增权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
<!-- Android 10+ 使用 MediaStore / Scoped Storage，无需 WRITE_EXTERNAL_STORAGE -->
<application android:requestLegacyExternalStorage="true" ...>
```

```gradle
<!-- android/app/build.gradle 关键配置 -->
android {
    defaultConfig {
        minSdk 23          // Flutter 3.27 要求 minSdk >= 23
        targetSdk 34
        // 启用 Jetifier 兼容旧插件
    }
    // 签名配置（发布必需）
    signingConfigs {
        release {
            storeFile file("../keystore.jks")
            storePassword "..."
            keyAlias "writer_assistant"
            keyPassword "..."
        }
    }
}
```

### 📦 构建产物对比

| 平台 | 命令 | 产物 | 备注 |
|------|------|------|------|
| Windows | `flutter build windows --release` | `.exe` + DLL | 需 VS2022 |
| **Android** | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` | 可直接安装/分发 |
| Android | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` | Play Console 上传必需 |

### 🔄 迭代建议

| 阶段 | 目标 | 关键交付 |
|------|------|----------|
| A1 | **最小可用** | 编译通过、数据库读写、AI 对话、基础编辑、单栏导航、APK 打包 |
| A2 | **体验对齐** | 响应式布局、工具栏适配、文件导入导出(分享面板)、长按菜单、虚拟键盘适配 |
| A3 | **原生感** | 启动图/闪屏、推送通知(写作提醒)、桌面快捷方式、生物识别锁应用、横屏/平板优化 |
| A4 | **发布就绪** | Play Console 上架、应用内更新、崩溃上报、混淆/加固、隐私政策合规 |

### 📌 适配原则

1. **单代码库、多端响应式** —— `LayoutBuilder`/`MediaQuery` 断点复用，不分仓
2. **桌面优先不倒退** —— 移动端适配不破坏现有桌面体验
3. **能力降级优雅** —— 移动端无法实现的功能（如多窗口拖拽）提供替代方案而非隐藏
4. **性能兜底** —— 低端机型内存/CPU 限制下大章节/大纲仍可流畅编辑