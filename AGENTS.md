# WriterAssistant - Agent Guide

## 项目概览

WriterAssistant 是一款**面向中文网文作者的 AI 辅助写作桌面应用**，使用 Flutter 构建，目标平台为 Windows（同时保留了 linux/macos/web 工程骨架）。

- **仓库**: `https://github.com/KongMingT/WriteAssistant.git`
- **框架**: Flutter 3.27 / Dart 3.6
- **状态管理**: Riverpod 2.x
- **数据库**: drift (SQLite ORM, 代码生成)，9 张表 / 7 个 DAO
- **AI 接入**: Dio (HTTP)，支持 DeepSeek/通义千问/OpenAI/Moonshot 四家供应商
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
│   │   ├── ai_client.dart             # Dio 客户端 (流式SSE + 自动重试拦截器)
│   │   ├── models/ai_model_config.dart # AiProvider 枚举 + API Key 安全存储 + Provider
│   │   └── prompts/prompts.dart       # 10 套提示词模板
│   ├── database/
│   │   ├── database.dart              # AppDatabase 定义 (schemaVersion=3)
│   │   ├── database.g.dart            # Drift 生成代码 (~8100行)
│   │   ├── providers.dart             # 7 个 DAO 的 Riverpod Provider
│   │   ├── tables/ (9张表)
│   │   │   ├── books.dart             # 书籍 (autor/status/genre/description/cover)
│   │   │   ├── volumes.dart           # 卷 (关联 book)
│   │   │   ├── chapters.dart          # 章节 (content 无长度限制, 关联 volume)
│   │   │   ├── characters.dart        # 角色 (关联 book)
│   │   │   ├── character_relations.dart # 角色关系 (无UI使用)
│   │   │   ├── outline_nodes.dart     # 大纲节点 (bookId/chapterId/parentId/type/status)
│   │   │   ├── plot_lines.dart        # 剧情线 (无UI使用)
│   │   │   ├── plot_nodes.dart        # 剧情节点 (无UI使用)
│   │   │   └── writing_sessions.dart  # 写作时段 (无写入)
│   │   └── daos/ (7个DAO)
│   │       ├── book_dao.dart          # 含 recalculateBookWordCount (SQL SUM)
│   │       ├── volume_dao.dart
│   │       ├── chapter_dao.dart
│   │       ├── character_dao.dart     # 含角色关系 CRUD
│   │       ├── outline_dao.dart       # 书籍级/章级大纲 + 批量插入
│   │       ├── plot_dao.dart          # 剧情线/节点 (未被调用)
│   │       └── session_dao.dart       # 写作会话 (未被调用)
│   ├── services/
│   │   ├── txt_import_service.dart    # TXT 导入 (编码检测 + 章节拆分)
│   │   ├── txt_export_service.dart    # TXT 导出 (单章/整书)
│   │   └── chapter_compress_service.dart # 章节压缩 → 摘要回写 outline_nodes
│   └── utils/
│       └── id_generator.dart          # UUID v4 生成器 (使用 uuid 包)
├── features/
│   ├── book_selection/
│   │   └── book_selection_screen.dart # 首页：书籍卡片网格 + 新建/导入/长按编辑/删除
│   ├── workspace/
│   │   ├── workspace_screen.dart      # 三栏布局 + 全局快捷键 + 导出菜单 + AppBar
│   │   ├── sidebar/chapter_tree.dart  # 卷→章节树 (右键菜单: 新建/重命名/删除)
│   │   ├── editor/chapter_editor.dart # 编辑器 (工具栏+标题+章纲+正文+自动保存+撤销重做)
│   │   ├── editor/search_dialog.dart  # Ctrl+F 全文搜索/替换
│   │   ├── ai_panel/ai_panel.dart     # AI 对话面板 (流式+上下文选择+大纲快捷操作)
│   │   └── models/selection_state.dart # 选中状态 + 信号 + AI 上下文 Provider
│   ├── outline/
│   │   ├── outline_screen.dart        # 书籍大纲管理页 (三栏: 大纲树|编辑器|AI面板)
│   │   └── outline_panel.dart         # 编辑器内嵌单章章纲面板
│   ├── character/
│   │   ├── character_sheet.dart       # 角色管理底部弹窗 (含编辑对话框)
│   │   └── character_list_screen.dart # (遗留) 旧版独立角色页，AI 面板"人物"快捷操作仍引用
│   ├── settings/settings_screen.dart  # AI 供应商配置 + 上下文选章上限 + 连接测试
│   └── book_analysis/book_analysis_screen.dart # 拆书分析 (导入 TXT → AI 分析 → 导入为书籍)
└── shared/
    ├── themes/theme_provider.dart     # 主题/字号/字体 Provider (持久化)
    └── widgets/
        ├── status_bar.dart            # 底部状态栏 (字数/速度/时长/已选章/主题切换)
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
- 工具栏：4 种中文字体（宋体/楷体/黑体/微软雅黑）、字号 12-32px、增加/减少缩进、自动排版全文、显示/隐藏章纲
- 自动保存：正文 3 秒防抖，标题 500ms 防抖；`Ctrl+S` 强制即时保存；离开编辑器立即保存
- 保存后通过 `bookDao.recalculateBookWordCount()` (SQL SUM) 同步更新 `books.wordCount`
- Tab 插入全角空格首行缩进，Enter 自动继承前导缩进（拦截键事件手动插入，无时序问题），Shift+Enter 跳过缩进
- 增/减缩进支持单段落与多行选中；自动排版为全文所有行补首行缩进
- `Ctrl+Z` / `Ctrl+Y` 撤销重做（`UndoStack` 手动快照，每 300ms 记录一次，Enter/Tab 自定义操作均可撤销）

### 全文搜索/替换 (Ctrl+F)
- `SearchDialog` 跨卷/章搜索标题和正文，显示匹配上下文（±20 字）
- 支持「替换一项」和「全部替换」（无正则，区分大小写）
- 点击结果跳转到对应章节并关闭对话框

### 书籍管理
- 书籍 → 卷 → 章节三级结构，侧边栏只显示当前书的卷/章节
- 侧边栏右键菜单：新建卷/章、重命名、删除（带确认对话框；删卷手动级联删章）
- 新建时自动命名（"第一卷"/"第一章"），新建章节按当前总数递增
- 导入 TXT（自动检测编码 UTF-8/GBK，按 `第[X]章/回/节/部` 拆分）
- 导出 TXT（单章或整书），格式为 标题+空行+正文

### 书籍大纲系统
- 工作区 AppBar「大纲」按钮进入 `OutlineScreen` 三栏页面（大纲树 | 节点编辑器 | AI 面板）
- `outline_nodes` 支持书籍级（bookId，根节点 `type=book_root`）+ 章级（chapterId）两级数据
- 节点类型：卷→章→节→剧情点，右键菜单可添加子节点/同级/删除（递归）
- 中间编辑区：标题 500ms 防抖、内容 3s 防抖实时保存；显示类型/字数/草稿·定稿状态；章节点可下拉关联章节
- 底部状态栏：节点总数 / 已定稿数 / 进度百分比；展开全部/折叠全部
- **AI 生成大纲可导入**：`_tryImportOutline` 解析 AI 返回的 JSON 大纲 → 递归生成节点 → 确认对话框 → 批量插入 `outline_nodes`

### 新书规划 + 章节压缩
- AI 面板「新书规划」：表单（概念/类型/角色/世界观/体量）→ `AiPrompts.bookPlanning()` 生成 5 维度 Markdown 规划
- 已有章节被选中时：自动调 `ChapterCompressService` 分批压缩（每批 ≤15000 字符）→ 逐章 ~300 字摘要 → 回写 `outline_nodes` (`type=chapter_summary`, `status=final`) → 摘要自动填入表单只读区

### AI 对话面板
- 流式 SSE 打字机效果 + 自动重试（超时/500 错误重试 2 次，指数退避）
- 10 种快捷操作：新书规划、细纲扩写、起名、卡文助手、拆书、人物、生成大纲、扩写节点、润色节点、生成细纲（后 4 项仅在大纲页选中节点后显示）
- **上下文选择**：面板内可折叠的卷→章节多选树，双击阈值（设置页可选 5/10 章上限 + 固定 20000 字符）；`_buildContext` 统一组装选中章节 + 当前章节前 2000 字 + 角色列表前 500 字
- 对话消息持久化于 `aiChatMessagesProvider`（甜跨面板生命周期，重启即失）
- 一键复制 AI 回复、清空对话、AI 面板内快捷进设置
- 面板文字与输入框复用编辑器字体设置

### 角色管理
- 工作区 AppBar「人物」→ 底部弹窗（不离开编辑区），标题带当前书名
- 角色卡片列表（类型标签：主角/反派/配角），CRUD 弹窗：姓名/类型/性别/年龄/性格/背景/外貌/备注
- 自动关联当前书籍

### 拆书分析
- 导入外部 TXT → AI 分析（人物/关系/节奏/技巧）→ 结果可复制、可导入为书籍

### 写作追踪
- 底部状态栏实时显示：字数、码字速度（字/时）、本次写作时长、AI 已选 N 章
- 一键切换深色/浅色主题（持久化）
- **注意**：写作数据仅内存统计，`writing_sessions` 表从未写入

### 快捷键
| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 强制保存当前章节 |
| `Ctrl+N` | 新建章节 |
| `Ctrl+Shift+N` | ⚠️ 已废弃（触发 `newBookRequestProvider` 但无监听者） |
| `Ctrl+E` | 导出当前章节 |
| `Ctrl+F` | 全文搜索/替换 |
| `Ctrl+Z` / `Ctrl+Y` | 撤销 / 重做（编辑器内） |

---

## 关键技术决策

### 状态管理: Riverpod
- `StateProvider` — 简单状态（选中章节/书籍、写作状态、信号、AI 上下文选择、AI 对话消息）
- `FutureProvider` — 异步配置（AI 配置）
- `StateNotifierProvider` — 可变设置（主题模式、字号、字体族，均持久化到 secure storage）
- `Provider` — 依赖注入（数据库、7 个 DAO）

### 信号驱动跨组件通信
使用 `StateProvider<int>` 作为信号：
- `treeRefreshProvider` — 目录树刷新
- `forceSaveProvider` — 强制保存（Ctrl+S 触发）
- `newChapterRequestProvider` — 全局新建章节（chapter_tree 监听）
- `outlineTreeRefreshProvider` — 大纲树刷新
- `newBookRequestProvider` — ⚠️ 无监听者（死代码）

### 页面路由
- `BookSelectionScreen` (首页) → `Navigator.push` → `WorkspaceScreen(bookId)`
- 工作区 AppBar 返回按钮 → `Navigator.pop` → 回到书籍选择页（返回后刷新列表）
- 大纲页 / 拆书 / 设置 / 角色弹窗均为独立路由或弹窗

### 数据库
- drift ORM，9 张表，7 个 DAO，`schemaVersion=3`
- 数据库文件路径：`getApplicationDocumentsDirectory()/writer_assistant.db`
- 使用 String UUID 作为主键（`uuid` 包 v4）
- `onUpgrade` 已实现 v1→v2（12 列新增）及 v2→v3（outline_nodes 新增 bookId/status）。**改表时必须同步更新 `schemaVersion` 和 `onUpgrade`**
- 外键默认无级联：`deleteBook` 在存在卷时可能触发 FK 约束错误（见待办 #14）

---

## 待完善 & 注意事项

### 🔴 P0 — 写作流畅度硬伤
1. ✅ **撤销/重做 (Ctrl+Z/Y)** — 已解决：`UndoStack` 手动快照
2. ✅ **全文搜索/替换 (Ctrl+F)** — 已解决：`SearchDialog`
3. ❌ **编辑器沉浸模式** — 写正文时需手动折叠侧栏/AI 面板，无一键全屏编辑器

### 🟡 P1 — 日常写作体验瓶颈
4. ❌ **章节拖拽排序** — 侧边栏仅右键菜单，无法拖拽调整卷/章顺序
5. ❌ **写作统计/趋势** — 状态栏仅本次数据；`writing_sessions` 表从未写入（`SessionDao.startSession/endSession` 无调用），无从做日/周趋势
6. ❌ **导出格式单一** — 仅 TXT，缺少 epub/markdown/pdf

### 🟢 P2 — 可用但难受
7. ❌ **角色信息编辑时不可见** — 无悬浮提示，需切弹窗
8. ❌ **AI 对话不持久化** — `aiChatMessagesProvider` 仅内存，重启丢失
9. ❌ **写作目标系统** — 无每日字数目标/进度条/完成反馈
10. ❌ **版本快照** — 每次保存直接覆盖，无法回退历史版本

### 📦 其他技术债务
11. ❌ **大章节性能** — `chapters.content` 无大小限制，长章节可能内存溢出
12. ❌ **导入格式增强** — TXT 正则遗漏 "序章"、"尾声"、"Chapter 1" 等格式；且拆分后章节标题统一为"第N章"，原文标题残留在正文中
13. ❌ **书籍删除级联** — `deleteBook` 不会级联删除卷/章节/角色/大纲；外键仍指向存在的卷时可能报 FK 约束错
14. ⚠️ **无 UI 的死数据表** — `plot_lines`/`plot_nodes`（剧情线）、`character_relations`（角色关系）、`writing_sessions` 表已建好但无任何 UI/调用方
15. ⚠️ **大纲导出未实现** — `outline_screen.dart` "导出大纲"按钮仅提示"待实现"
16. ⚠️ **AI 大纲导入依赖根节点** — `_tryImportOutline` 要求 `book_root` 已存在（需先打开过一次大纲页），否则静默失败
17. ⚠️ **死代码/未用模板** — `AiPrompts.writerBlock`/`expandOutline`/`generateChapterOutline` 未被调用（快捷操作用内联文本）；`newBookRequestProvider` 无监听；`AiModelConfig` 的 endpoint/model 自定义字段与 `AiStorageKeys.customEndpoint/customModel` 未使用，设置页无自定义模型/端点配置
18. ⚠️ **`getOutlineByBook` 未过滤 `chapterId=''`** — 会把 `chapter_summary`（章节摘要，设置了 bookId）与书籍级大纲节点混在一起返回
19. 🛠 **lint 噪音** — `flutter analyze` 报告 235 条 info（多为 `prefer_const_constructors`）与 3 条 unused_import warning
20. 🔮 **远期** — 多语言 / 日志 / 自动更新 / 云同步

---

## 已实现专题

### 书籍大纲系统

#### 目标
构建完整的**书籍级大纲系统**，支持创作/管理/编辑、与 AI 深度集成。

#### 数据结构（`outline_nodes`，schemaVersion 3）
| 列 | 说明 |
|----|------|
| `bookId` | 书籍级大纲节点用（nullable，引用 Books） |
| `chapterId` | NOT NULL；书籍级节点用空字符串 `''` 占位，章级节点用真实章节 ID |
| `parentId` | 父节点（nullable），卷→章→节→剧情点无限嵌套 |
| `type` | `'book_root' \| 'volume' \| 'chapter' \| 'section' \| 'beat' \| 'outline' \| 'chapter_summary'` |
| `title` | 节点标题 |
| `content` | 节点内容（nullable） |
| `sortOrder` | 同级排序 |
| `status` | `draft \| final`（默认 draft） |
| `createdAt`/`updatedAt` | 预留 |

**关系模型：**
```
Book (1) ──→ OutlineNode (N, bookId)
  ├── type='book_root'    (书籍概要, 单条, 每本书自动创建)
  ├── type='volume' (卷) → type='chapter' (章) → type='section' (节) / type='beat' (剧情点)
  └── chapterId=X 的节点  (单章细纲, 编辑器内嵌面板展示)
```

#### `OutlineDao` 关键方法
`getOutlineNodesByChapter` / `getBookRoot` / `getOutlineByBook` / `getOutlineNodesByParent` / `insertOutlineNode` / `insertOutlineNodes`(批量事务) / `updateOutlineNode` / `deleteOutlineNode` / `deleteOutlineByBook`

#### AI 生成大纲导入流程
`ai_panel.dart: _showGenerateOutlineDialog` → `AiPrompts.generateOutline` → 对话区展示 → `_tryImportOutline` 提取 ```json 块 → 递归 `_jsonToCompanions` → 确认对话框 → `insertOutlineNodes` 批量插入 → 刷新大纲树

#### 页面对接
- `workspace_screen.dart` AppBar「大纲」按钮 → `OutlineScreen(bookId)`
- `outline_panel.dart`（编辑器章纲面板）右上角「书籍大纲」入口
- `selection_state.dart`：`selectedOutlineNodeProvider` + `outlineTreeRefreshProvider`
- AI 面板大纲快捷操作需先在大纲页选中节点（`selectedOutlineNodeProvider` 非空才显示）

### 新书规划助手
- `AiPrompts.bookPlanning()` — 5 维度 Markdown 规划（世界观/主线暗线/角色弧光/卷结构/节奏爽点）
- `ChapterCompressService` — 分批压缩（每批 ≤15000 字符）、正则解析 `## 章节 #N\n标题：..\n摘要：..`、覆盖回写 `outline_nodes`（先删该章旧节点再插入 `chapter_summary`，`status=final`）
- `_showBookPlanningDialog` — 表单；已有章节摘要自动填入只读区
- 可复用性：`ChapterCompressService(aiClient, outlineDao)` 可在拆书页复用

### AI 对话上下文选择
- `selectedContextChaptersProvider`（`Set<String>`）+ `aiContextConfigProvider`（章节数上限 5/10，固定 20000 字符）
- AI 面板内可折叠卷→章节多选树；设置页 `<SegmentedButton>` 切 5/10 章；状态栏显示"已选 N 章"
- `_buildContext` 组装顺序：选中章节（按 sortOrder 降序）→ 当前编辑章节前 2000 字 → 角色列表前 500 字 → 截断 20000
- **扩展点**：字数上限可配置、选择持久化、排除当前章节开关、按卷全选、上下文预览

### 撤销/重做（UndoStack）
- `lib/shared/widgets/undo_stack.dart`：双栈（undo/redo）管理 `TextEditingValue`，去重 (`_lastSnapshot`)，容量 200，push 时清空 redo 栈
- 编辑器 `onKeyEvent` 拦截 Ctrl+Z/Y；Enter/Tab/缩进/自动排版等自定义操作均记录快照；`_isUndoingRedoing` 防循环触发
- 切换章节时 `_undoStack.clear()`

### 全文搜索/替换（SearchDialog）
- 跨卷/章遍历，标题与正文分别匹配；正文给出 ±20 字上下文
- 300ms 防抖；`_replaceOne` 按 matchIndex 精准替换单处；`_replaceAll` 遍历全部章节 `replaceAll`
- 替换后刷新目录树并重新搜索

### Utf8Decoder 流式类型错误（已修复）
`ai_client.dart:86` 使用 `(response.data.stream as Stream<Uint8List>).cast<List<int>>()` 包装流，配合 `import 'dart:typed_data'`，解决 `StreamTransformer<Uint8List,String>` 与 `StreamTransformer<List<int>,String>` 的泛型不变性不匹配问题。拆书页走非流式 `chat()`，不受影响。

---

## 已知细节 & 边界

1. **章级大纲（outline_panel）节点不带 bookId**，与书籍级大纲通过 `chapterId` 关联；点击章纲中某节点跳转到章节编辑时，编辑器内章纲面板展示 `chapterId == 当前章` 的节点
2. **`AiProvider` 默认端点/模型硬编码在 `ai_client.dart`**（`_getEndpoint`/`_defaultModel`），`AiModelConfig` 的自定义 endpoint/model 未参与实际请求
3. **AI 面板 `_quickAction` 的 'expand'（细纲扩写）与 'writerBlock'（卡文助手）发送的是需用户自行填写的模板文本**，并非自动抓取章纲/正文
4. **`_selectLatestChapter`** 按 sortOrder 取全书最大章节，进入工作区自动定位
5. **字符/字数统计基于 `content.length`**（含标点换行），非中文分词统计
6. **测试**：7 个 DAO + ChapterCompressService + widget test 共 49 个用例全部通过；测试用 `AppDatabase(executor: NativeDatabase.memory())` 在内存库中运行

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

**当前状态**: `flutter analyze` 无 error（235 条 lint info + 3 条 unused_import warning）；`flutter test` 49 用例全绿。