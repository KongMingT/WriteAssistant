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
2. **AI 大纲导入依赖根节点** — `_tryImportOutline` 要求 `book_root` 已存在（需先打开过一次大纲页），否则静默失败
3. **死代码/未用模板** — `AiPrompts.writerBlock`/`expandOutline`/`generateChapterOutline` 未被调用（快捷操作用内联文本）
4. **`getOutlineByBook` 未过滤 `chapterId=''`** — 会把 `chapter_summary`（章节摘要，设置了 bookId）与书籍级大纲节点混在一起返回
5. 🔮 **远期** — 多语言 / 日志 / 自动更新 / 云同步 / AI 对话 token 上限自定义 / 章节批量处理

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
7. **测试**：9 个 DAO + 3 个 Service + widget 共 70 个用例全部通过；测试用 `AppDatabase(executor: NativeDatabase.memory())` 在内存库中运行
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

**当前状态**: `flutter analyze` 无 error / 无 warning（仅 tools/ 脚本 2 条 avoid_print info 可忽略）；`flutter test` 70 用例全绿。

---

## Git 组织

- 每完成一个功能批次：`flutter analyze` + `flutter test` 验证通过后提交并推送
- 提交信息风格：`feat:/fix:/chore: 中文描述 (+ 可选的要点列表)`
- 历史批次提交：A 技术债清理(519f5ba) / B 自定义端点(1f31850) / C 沉浸模式(1f31850→08c580a 前 b1f? 见 `git log`) / D 拖拽(1f31850, 08c580a) / E 写作统计(1b67b21) / F 导出(39a0453) / G 导入+级联+性能(294b7b8) / H1+H2 AI持久化+快照(0278c08) / H3+H4 悬浮提示+每日目标(1ca3f5e) / I lint( b571532)