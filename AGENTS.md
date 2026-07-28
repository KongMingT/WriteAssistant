# WriterAssistant - Agent Guide

## 项目概览

WriterAssistant 是一款**面向中文网文作者的 AI 辅助写作桌面应用**，使用 Flutter 构建，目标平台为 Windows。

- **仓库**: `https://github.com/KongMingT/WriteAssistant.git`
- **仓库**: `https://github.com/KongMingT/WriteAssistant.git`
- **框架**: Flutter 3.27 / Dart 3.6
- **状态管理**: Riverpod 2.x
- **数据库**: drift (SQLite ORM, 代码生成)
- **AI 接入**: Dio (HTTP), 支持 DeepSeek/通义千问/OpenAI/Moonshot 四家供应商
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
│   │   ├── models/ai_model_config.dart # AiProvider 枚举 + 安全存储 + Riverpod Provider
│   │   └── prompts/prompts.dart       # 5 套提示词模板
│   ├── database/
│   │   ├── database.dart              # AppDatabase 定义
│   │   ├── database.g.dart            # Drift 生成代码 (~8800行)
│   │   ├── providers.dart             # 所有 DAO 的 Riverpod Provider
│   │   ├── tables/ (9张表)
│   │   │   ├── books.dart             # 书籍
│   │   │   ├── volumes.dart           # 卷 (关联 book)
│   │   │   ├── chapters.dart          # 章节 (含 content, 关联 volume)
│   │   │   ├── characters.dart        # 角色 (关联 book)
│   │   │   ├── character_relations.dart # 角色关系
│   │   │   ├── outline_nodes.dart     # 大纲节点 (关联 chapter, 支持层级parentId)
│   │   │   ├── plot_lines.dart        # 剧情线 (关联 book)
│   │   │   ├── plot_nodes.dart        # 剧情节点 (关联 plot_line)
│   │   │   └── writing_sessions.dart  # 写作时段
│   │   └── daos/ (7个DAO)
│   ├── services/
│   │   ├── txt_import_service.dart    # TXT 导入 (编码检测 + 章节拆分)
│   │   └── txt_export_service.dart    # TXT 导出 (单章/整书)
│   └── utils/
│       └── id_generator.dart          # UUID v4 生成器 (使用 uuid 包)
├── features/
│   ├── book_selection/
│   │   └── book_selection_screen.dart # 首页：书籍卡片网格，点击进入工作区
│   ├── workspace/
│   │   ├── workspace_screen.dart      # 三栏布局编排 + 键盘快捷键 + 导出菜单
│   │   ├── sidebar/chapter_tree.dart  # 纯卷→章节树 (接受 bookId, 无书籍层级)
│   │   ├── editor/chapter_editor.dart # 编辑器 (工具栏+标题+章纲+正文+自动保存)
│   │   ├── ai_panel/ai_panel.dart     # AI 对话面板 (流式 + 上下文)
│   │   └── models/selection_state.dart # 选中状态 + 信号 Provider
│   ├── outline/outline_panel.dart     # 章纲面板 (可折叠, 增删改)
│   ├── character/
│   │   ├── character_sheet.dart       # 角色管理弹窗 (+编辑对话框)
│   │   └── character_list_screen.dart # (遗留) 旧版独立角色页
│   ├── settings/settings_screen.dart  # AI 供应商配置 + 连接测试
│   └── book_analysis/book_analysis_screen.dart # 拆书分析
└── shared/
    ├── themes/theme_provider.dart     # 主题/字体 Provider
    └── widgets/status_bar.dart        # 底部状态栏 (字数/速度/时长/主题切换)
```

---

## 当前功能清单

### 书籍选择首页
- 启动后显示书籍卡片网格（书名 + 字数）
- 点击卡片进入工作区，长按删除
- 右下角新建书籍按钮，导入 TXT 按钮
- 新建/导入后自动跳转工作区
- AppBar 返回按钮回到书籍选择页

### 编辑器
- 三栏可拖拽布局（目录 | 编辑器 | AI 面板），面板可折叠
- 自动保存：正文 3 秒防抖，标题 500ms 防抖；`Ctrl+S` 强制即时保存
- 4 种中文字体（宋体/楷体/黑体/微软雅黑），字号 12-32px
- Tab 插入全角空格首行缩进，Enter 自动继承前导缩进（拦截键事件手动插入，无时序问题）
- 增加/减少缩进（支持单段落和多行选中），自动排版全文
- 编辑器内嵌**章纲面板**（可折叠），支持大纲节点的添加/编辑/删除

### 书籍管理
- 书籍 → 卷 → 章节三级结构，侧边栏只显示当前书的卷/章节
- 侧边栏右键菜单：新建卷/章、重命名、删除（带确认对话框）
- 自动命名（新建时生成 "第一卷"/"第一章" 等）
- 导入 TXT（自动检测编码 UTF-8/GBK，按章节拆分）
- 导出 TXT（单章节或整本书）

### AI 辅助
- 4 家供应商（DeepSeek/通义千问/OpenAI/Moonshot），API Key 安全存储
- **流式响应**（SSE 打字机效果）
- **自动重试**（超时/500 错误重试 2 次，指数退避）
- 5 种快捷操作：大纲梳理、细纲扩写、起名助手、卡文助手、拆书分析
- 快捷操作自动携带上下文（当前章节前 2000 字 + 书籍角色列表）
- 一键复制 AI 回复，清空对话

### 角色管理
- 从工作区 AppBar 人物按钮打开 **底部弹窗**，不离开编辑区
- 弹窗标题显示 "《书名》- 人物管理"
- 角色卡片列表（角色类型标签：主角/反派/配角）
- CRUD 弹窗：姓名、角色类型、性别、年龄、性格、背景、外貌、备注
- 自动关联当前书籍

### 拆书分析
- 导入外部 TXT 进行 AI 分析
- 分析结果导入为书籍
- 结果一键复制

### 写作追踪
- 底部状态栏实时显示：字数、码字速度（字/时）、本次写作时长
- 一键切换深色/浅色主题

### 快捷键
| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 强制保存当前章节 |
| `Ctrl+N` | 新建章节 |
| `Ctrl+E` | 导出当前章节 |

---

## 关键技术决策

### 状态管理: Riverpod
- `StateProvider` — 简单状态（选中章节/书籍、写作状态、刷新信号、强制保存信号）
- `FutureProvider` — 异步配置（AI 配置）
- `StateNotifierProvider` — 可变设置（主题模式、字号、字体族）
- `Provider` — 依赖注入（数据库、DAO）

### 信号驱动跨组件通信
使用 `StateProvider<int>` 作为信号：
- `treeRefreshProvider` — 目录树刷新
- `forceSaveProvider` — 强制保存（快捷键 Ctrl+S 触发）
- `newChapterRequestProvider` — 全局新建章节

### 页面路由
- `BookSelectionScreen` (首页) → `Navigator.push` → `WorkspaceScreen(bookId)`
- 工作区 AppBar 返回按钮 → `Navigator.pop` → 回到书籍选择页
- 角色管理、拆书、设置均为独立路由或弹窗

### 数据库
- drift ORM，9 张表，7 个 DAO
- 数据库文件路径：`getApplicationDocumentsDirectory()/writer_assistant.db`
- 使用 String UUID 作为主键（`uuid` 包 v4）
- **注意**: `schemaVersion=3`，`onUpgrade` 已实现 v1→v2（12 列新增）及 v2→v3（outline_nodes 新增 bookId/status）迁移逻辑。改表时必须同步更新 `schemaVersion` 和 `onUpgrade`

---

## 最近改动

| 改动 | 说明 |
|------|------|
| AI 生成大纲结果入库 | `_tryImportOutline` 解析 AI 返回的 JSON 大纲，递归生成 `OutlineNodesCompanion`，确认对话框后批量插入 `outline_nodes` 表，刷新大纲树 |
| 书籍大纲系统实现 | 完成步骤 4-8：新增提示词模板、`outline_screen.dart` 三栏页面、工作区入口、AI 面板大纲快捷操作、"生成大纲"概念输入对话框、章纲面板入口 |
| OutlineDao 测试全覆盖 | 新增 9 个测试覆盖 `getBookRoot`/`getOutlineByBook`/`getOutlineNodesByParent`/`insertOutlineNodes`/`deleteOutlineByBook`，OutlineDao 测试从 4 个增至 13 个 |
| DAO 单元测试 | 7 个 DAO 共 42 个测试用例全部通过（OutlineDao 新增 9 个书籍级大纲方法测试）。`AppDatabase` 重构为接受可选 `QueryExecutor` 以支持 `NativeDatabase.memory()` 测试。新增 `sqlite3` dev 依赖 |
| AI 面板滚动闪烁修复 | `_scrollToBottom` 增加 `_isNearBottom` 检查，用户离开底部 50px 时停止自动滚动 |
| AI 面板字体同步 | AI 面板文字和输入框复用编辑器字体 (`editorFontFamilyProvider`)，跟随用户选择的宋体/楷体/黑体/微软雅黑 |
| 构建 | `flutter build windows --debug` 成功 |


| 回车缩进重写 | 拦截 Enter 键手动插入 `\n` + 前导全角空格，不再依赖 `Future.microtask`，Shift+Enter 跳过缩进 |
| 角色管理 -> 弹窗 | `character_sheet.dart` 新建，工作区内 `showModalBottomSheet` 展示角色列表，显示当前书名 |
| 书籍选择首页 | `book_selection_screen.dart` 新建，卡片网格展示所有书籍，点击进入工作区 |
| 侧边栏重构 | `chapter_tree.dart` 接受 `bookId`，只显示该书的卷/章节，删除书籍层级管理代码 |
| 工作区重构 | `workspace_screen.dart` 接受 `bookId` 参数，AppBar 显示书名 + 返回按钮 |
| 首页路由 | `app.dart` home 改为 `BookSelectionScreen` |
| 书籍卡片美化 | 仿实体书比例，渐变封面 + 书名首字母 + 书名栏 |
| 编辑书名 | 长按卡片或菜单栏可编辑书名，同步修改数据库 |
| 自动定位最新章节 | 进入工作区自动选中 `sortOrder` 最大的章节 |
| 应用图标 | 替换为自定义图标（紫色背景 + W 字母） |
| TextEditing 原子化 | 所有文本修改统一使用 `TextEditingValue` 避免光标错位 |
| 文件清理 | `workspace_screen.dart` 移除导入 TXT 和新建书籍逻辑（移至首页） |
| 字数同步修复 | 保存章节后通过 `bookDao.recalculateBookWordCount()` (SQL SUM) 同步更新 `books.wordCount` |
| 数据库迁移 v1→v2 | 新增 12 列：books(author,status,genre), volumes(updatedAt), character_relations(createdAt), outline_nodes(createdAt,updatedAt), plot_lines(sortOrder,createdAt), plot_nodes(createdAt,updatedAt), writing_sessions(chapterId) |
| Utf8Decoder 类型错误修复 | `ai_client.dart:85-86` 使用 `.cast<List<int>>()` 包装流类型，修复 `Utf8Decoder` 不兼容 `Stream<Uint8List>` 的问题；增补 `import 'dart:typed_data'` |
| AI 对话章节上下文选择 | 实现方案详见下节「AI 对话上下文选择」- 新增 `selectedContextChaptersProvider` / `aiContextConfigProvider`，AI面板内嵌多选章节树，设置页可选5/10章上限，状态栏显示选中概要，上下文全局作用于所有消息 |
| 数据库迁移 v2→v3 (大纲系统) | `outline_nodes` 新增 `bookId`/`status` 列，`type` 默认值保留，`chapterId` 保持 NOT NULL（书籍级节点使用空字符串 `''` 占位兼容迁移）；`OutlineDao` 新增 `getBookRoot`/`getOutlineByBook`/`getOutlineNodesByParent`/`insertOutlineNodes` 批量方法；`schemaVersion` 3，`onUpgrade` v2→v3 添加 `bookId` 和 `status` 列 |

---

## 待完善 & 注意事项

### 高优先级
1. **大章节性能** — `chapters.content` 为 `TextColumn` 无大小限制，长篇章节可能导致内存问题。可考虑分页加载或惰性加载。
2. **导入格式增强** — 当前 TXT 导入正则 `(第[一二三四五六七八九十百千万０-９0-9]+[章回节部])` 会遗漏 "序章"、"尾声"、"Chapter 1" 等格式。

### 中优先级
3. **搜索功能** — 缺少全局搜索/替换，对大型作品影响较大。
4. **书籍删除级联** — `book_dao.dart` 的 `deleteBook` 不会级联删除卷和章节，需要手动处理。

### 低优先级
5. **多语言支持** — 所有 UI 字符串硬编码为中文，未做 i18n。
6. **日志系统** — 无正式日志框架，`avoid_print` lint 开启但无处输出。
7. **自动更新** — 无版本检测/更新机制。
8. **云同步** — 无云端备份/同步功能。

---

## 书籍大纲系统（下一阶段重点开发）

### 目标
构建一套完整的**书籍级大纲系统**，支持创作/管理/编辑/导出，与 AI 深度集成。

### 当前现状与问题

| 维度 | 现状 | 问题 |
|------|------|------|
| 数据结构 | `outline_nodes` 表仅绑定 `chapterId`，无书籍级大纲概念 | 无法管理整本书的结构骨架 |
| 层级 | `parentId` 字段存在但 UI 未使用 | 单层拍平，无卷→章→节树形结构 |
| 编辑 UI | `OutlinePanel` 嵌入在编辑器中，只显示当前章的单章大纲 | 不能以书籍视角概览全局 |
| AI 生成 | "大纲梳理"快捷操作仅生成文本到对话区，不落地 | AI 结果与数据库脱节，无法迭代编辑 |
| 用户补充 | 无独立页面，所有操作局限于弹窗 | 书写长纲体验差 |

### 设计

#### 1. 数据模型（数据库迁移 → schemaVersion 3）

**`outline_nodes` 表改造：**

| 列 | 变更 | 说明 |
|----|------|------|
| `bookId` | **新增**，`text().nullable().references(Books, #id)()` | 书籍级大纲根节点用 |
| `chapterId` | 现有（NOT NULL），书籍级节点使用空字符串 `''` 占位 | 迁移兼容：SQLite 不支持 ALTER COLUMN 移除 NOT NULL；细纲链接到章节用真实 chapterId |
| `parentId` | 现有（nullable），**启用层级 UI** | 卷→章→节，支持无限嵌套 |
| `type` | 现有，扩展值 `'book_root' \| 'volume' \| 'chapter' \| 'section' \| 'beat'` | 标识节点类型 |
| `title` | 现有 | 节点标题（如"第一卷 少年崛起"、"第1章 穿越"） |
| `content` | 现有 | 节点内容描述 |
| `sortOrder` | 现有 | 同级排序 |
| `status` | **新增**，`text().withDefault('draft')` | `draft \| final` |

**关系模型：**
```
Book (1) ──→ OutlineNode (N, bookId)
  ├── type='volume' (卷)
  │   ├── type='chapter' (章)
  │   │   ├── type='section' (节)
  │   │   └── type='beat' (剧情节拍)
  │   └── ...
  └── type='book_root' (书籍概要，单条)
```

**查询原则：**
- 加载大纲：`bookId == X AND chapterId IS NULL`，按 `sortOrder` 排序
- 加载单章细纲：`chapterId == X`，关联到编辑器大纲面板
- 二者通过 `outline_nodes.type` 区分：`'book_root'/'volume'/'chapter'` vs `'section'/'beat'`

#### 2. 新增页面：`outline_screen.dart`

**路由**: `Navigator.push → OutlineScreen(bookId)`，从工作区 AppBar 大纲按钮进入

**布局**（仿三栏但有区别）：
```
┌─────────────────────────────────────────────────────────┐
│  AppBar: 《书名》- 大纲管理  [返回]  [保存]  [导出]     │
├────────────┬─────────────────────────┬───────────────────┤
│  左侧大纲树  │    中间编辑器区域         │  右侧 AI 面板      │
│  (卷→章→节) │  ┌─────────────────┐   │  (与工作区 AI 面板  │
│            │  │  节点标题 (可编辑)  │   │   共享 Provider)   │
│  右击菜单：  │  ├─────────────────┤   │                   │
│  添加子节点  │  │  节点内容 (可编辑)  │   │  AI 快捷操作：     │
│  添加同级    │  ├─────────────────┤   │  · 生成大纲(从概念) │
│  删除       │  │  字数/状态/关联章节 │   │  · 扩写选中节点   │
│  展开/折叠   │  └─────────────────┘   │  · 润色当前节点   │
│            │                          │  · 生成细纲→章节  │
│            │                          │                   │
├────────────┴─────────────────────────┴───────────────────┤
│  底部状态栏: 总节点数 / 已定稿数 / 进度百分比            │
└─────────────────────────────────────────────────────────┘
```

**左侧大纲树结构:**
- 顶层显示书名（根节点，不可删除）
- 子节点按 `sortOrder` 排列
- 缩进 + 图标区分类型（卷=📂 章=📄 节=📝 剧情节拍=⚡）
- 选中节点 → 中间编辑区显示详情
- 拖拽排序（可选）

**中间编辑区:**
- `title`：TextField，实时保存（500ms 防抖）
- `content`：TextField（多行），实时保存（3s 防抖）
- 元信息：类型标签、字数、关联章节（可选）
- 关联章节：下拉选择该卷下的章节，建立 `chapterId` 关联

#### 3. AI 集成

**新增提示词模板（`prompts.dart`）:**

```dart
/// 从故事概念生成书籍级大纲
static String generateOutline(String storyConcept, {String characters = '', String worldBuilding = ''})

/// 扩写大纲节点
static String expandOutlineNode(String title, String currentContent)

/// 从大纲节点生成章节细纲
static String generateChapterOutline(String volumeTitle, String chapterTitle, String context)
```

**AI 面板快捷操作（大纲专属）：**

| 操作 | 触发 | 组装上下文 |
|------|------|-----------|
| 生成大纲 | 用户填写故事概念，点击"AI 生成" | 概念文本 + 角色列表 + 设定 |
| 扩写选中节点 | 选中一个节点 | 节点标题/内容 + 父级上下文 |
| 润色节点 | 选中一个节点 | 节点内容 + AI 润色指令 |
| 生成细纲→章节 | 选中一个章节节点 | 卷+章大纲 + 角色列表 → 写入章节 |

**上下文注入**：复用 `_buildContext()` 逻辑，自动携带选中的上下文章节 + 角色列表。

**输出解析**：
AI 返回格式约定为 JSON/结构化 Markdown，前端解析后转换为 `outline_nodes` 行批量插入。

```json
[
  {"title": "第一卷 少年崛起", "type": "volume", "children": [
    {"title": "第1章 穿越异世", "type": "chapter", "content": "主角意外穿越...", "children": [
      {"title": "穿越醒来", "type": "section", "content": "主角发现身处山林..."},
      {"title": "获得系统", "type": "beat", "content": "金手指激活，获得新手礼包"}
    ]},
    {"title": "第2章 初露锋芒", "type": "chapter", ...}
  ]}
]
```

#### 4. 工作区整合

**AppBar 新增大纲按钮**（`workspace_screen.dart`）：
```
IconButton(
  icon: Icon(Icons.account_tree_outlined),
  tooltip: '书籍大纲',
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => OutlineScreen(bookId: widget.bookId),
  )),
)
```

放置于人物管理按钮之前。

**现有 `OutlinePanel` 保留**：
- 仍作为编辑器内嵌的"单章细纲面板"
- 数据独立：`chapterId != null` 的 outline_nodes
- 与书籍大纲通过 `chapterId` 关联互通

#### 5. 实现进度

| 步骤 | 文件 | 状态 |
|------|------|------|
| 1. 数据表改造 | `outline_nodes.dart` — 新增 `bookId`/`status`，保留 `chapterId` NOT NULL（书籍级用 `''` 占位） | ✅ 已完成 |
| 2. 数据库迁移 | `database.dart` — schemaVersion 3，v2→v3 迁移新增 `bookId`/`status` | ✅ 已完成 |
| 3. DAO 新增方法 | `outline_dao.dart` — `getBookRoot`/`getOutlineByBook`/`getOutlineNodesByParent`/`insertOutlineNodes`/`deleteOutlineByBook` | ✅ 已完成 |
| 4. AI 提示词 | `prompts.dart` — 新增 `generateOutline`/`expandOutlineNode`/`generateChapterOutline` 三个模板 | ✅ 已完成 |
| 5. 大纲编辑器页面 | `outline_screen.dart` — **新建**，三栏布局（大纲树 \| 编辑器 \| AI 面板） | ✅ 已完成 |
| 6. 工作区入口 | `workspace_screen.dart` — AppBar 新增大纲按钮 | ✅ 已完成 |
| 7. AI 面板集成 | `ai_panel.dart` — 快捷操作新增大纲相关选项 | ✅ 已完成 |
| 8. 单章细纲面板适配 | `outline_panel.dart` — 增加打开书籍大纲的入口 | ✅ 已完成 |

#### 6. 涉及文件明细

| 文件 | 改动 |
|------|------|
| `lib/core/database/tables/outline_nodes.dart` | 新增 `bookId`、`status` 列；`chapterId` 保持 NOT NULL（书籍级节点使用 `''` 占位） |
| `lib/core/database/database.dart` | schemaVersion 2 → 3，新增 onUpgrade v2→v3 迁移（addColumn bookId + status） |
| `lib/core/database/daos/outline_dao.dart` | 新增 `getBookRoot`、`getOutlineByBook`、`getOutlineNodesByParent`、`insertOutlineNodes`（批量）、`deleteOutlineByBook` |
| `lib/core/ai/prompts/prompts.dart` | 新增 outline 生成/扩写/润色提示词 |
| `lib/features/outline/outline_screen.dart` | **新建**：大纲编辑器主页面（三栏） |
| `lib/features/outline/outline_panel.dart` | 保留单章细纲面板，增加打开书籍大纲的入口 |
| `lib/features/workspace/workspace_screen.dart` | AppBar 新增大纲按钮 |
| `lib/features/workspace/ai_panel/ai_panel.dart` | 快捷操作新增大纲相关选项 |

#### 7. 边界 & 注意事项

1. **数据一致性**：书籍大纲节点删除时，如果已关联章节，提示用户解除关联
2. **AI 输出容错**：AI 返回格式可能不完整，前端已实现 JSON 提取与解析容错，解析失败时仍可在对话区手动复制使用
3. **大篇幅性能**：上百节点的大纲树建议按需加载（懒展开）
4. **多用户协作**：当前无此需求，但 `outline_nodes` 有 `createdAt`/`updatedAt` 为未来预留
5. **持久化 vs 暂存**：AI 生成的草稿自动保存到 `outline_nodes`（`status=draft`），用户确认后标记 `final`
6. **与编辑器的联动**：大纲节点生成章节细纲时，批量创建 `outline_nodes`（`chapterId=章节ID`），编辑器内的大纲面板自动刷新

---

## AI 对话上下文选择（已实现）

### 目标
在 AI 对话面板中提供一个"多选章节"的 UI，让用户自主选择哪些章节的内容作为 AI 对话的上下文背景，而不是每次都自动塞入当前章节。

### 实现概要
- `selectedContextChaptersProvider`（`StateProvider<Set<String>>`）存储用户勾选的章节 ID 集合
- `aiContextConfigProvider`（`StateProvider<AiContextConfig>`）存储配置（上限章节数、字数上限）
- AI 面板内嵌可折叠的卷→章节树，每章前有 Checkbox
- 双重阈值：设置页可选 5/10 章上限，固定 20000 字符上限
- `_buildContext` 方法统一组装选中章节 + 当前编辑章节前 2000 字 + 角色列表，注入所有消息
- 状态栏显示"已选 N 章"

### 当前问题
- `_quickAction`（`ai_panel.dart:112-131`）自动取当前选中章节的前 2000 字作为上下文
- 普通文字消息（`_sendMessage`）完全不包含任何章节上下文
- 用户无法选择用哪些章节作为上下文，也无法控制上下文的量

### 实现方案

#### 1. 章节选择状态（Provider）
新增 `selectedContextChaptersProvider`（`StateProvider<Set<String>>`）存储用户勾选的章节 ID 集合。

#### 2. AI 面板内嵌章节选择器
- 在 AI 面板折叠区域展示卷 → 章节树（复用或引用 `chapter_tree.dart` 的数据逻辑）
- 每章节前加 **Checkbox** 供多选
- 显示每章标题 + 字数
- 底部显示概要："已选 N 章，共 M 字（限制 N 章 / 20000 字）"

#### 3. 双重阈值限制
- **章节数上限**: 配置化，默认 10，用户可在设置中切换 5 / 10
- **字数上限**: 固定 20000 字符（含角色信息）
- 选章超出任一阈值时：按 sortOrder 顺序保留最新的章节，旧章节自动取消勾选（或提示用户）

#### 4. 上下文组装逻辑（`_buildContext` 方法抽取）
每次发消息前（`_sendMessage` 和 `_quickAction` 统一走此逻辑）：
1. 收集 `selectedContextChaptersProvider` 中所有章节内容
2. 自动包含当前编辑章节（`selectedChapterProvider`，但内容只取前 2000 字避免重复冗余）
3. 自动包含当前书籍角色列表（字符 < 500，若超则取前 500）
4. 按 `sortOrder` 降序拼接，截断至 20000 字
5. 组装为固定格式文本，注入到 user message 末尾

**注入时机**：
- **快捷操作**: 拼入已构造的 prompt 中
- **手动输入**: 自动附加在用户输入文本之后，以 `---\n【当前上下文】\n...` 分隔

#### 5. 状态栏同步
`status_bar.dart` 显示 "📄 已选 N 章" 提示（复用 `writingStateProvider` 或新增 `aiContextStateProvider`）。

### 涉及文件
| 文件 | 改动 |
|------|------|
| `lib/features/workspace/ai_panel/ai_panel.dart` | 新增章节选择器 UI，重构 `_sendMessage` 上下文组装 |
| `lib/features/workspace/models/selection_state.dart` | 新增 `selectedContextChaptersProvider`、`aiContextConfigProvider` |
| `lib/shared/widgets/status_bar.dart` | 显示选中章节概要 |
| `lib/features/settings/settings_screen.dart` | 可选："上下文选章上限 5/10" 配置项 |

### 扩展点
- **自定义字数上限**：当前固定 20000，后续可改为用户可配
- **选择持久化**：当前仅内存状态，后续可存到 `writing_sessions` 表
- **排除当前章节**：如果用户不想自动包含当前编辑章节，可加开关
- **按卷全选/反选**：卷标题旁加全选 checkbox
- **上下文预览**：选中章节后展示片段预览，方便确认内容是否合适

---

## Utf8Decoder 类型错误（已修复）

### 错误信息
```
❌ 请求失败: type 'Utf8Decoder' is not a subtype of type 'StreamTransformer<Uint8List, String>' of 'streamTransformer'
```

### 根因
`ai_client.dart:85-86` 中，Dio 5.4 流式响应返回 `Stream<Uint8List>`，但 `Utf8Decoder` 的类型是 `StreamTransformer<List<int>, String>`。Dart 泛型在运行时不变（invariant），即使 `Uint8List implements List<int>`，`StreamTransformer<Uint8List, String>` 与 `StreamTransformer<List<int>, String>` 仍视为不同类型，导致类型转换失败。

拆书页使用非流式 `client.chat()` 方法（`book_analysis_screen.dart:149`），不涉及流转换，因此不受影响。

### 修复方案
将 `ai_client.dart:85-86`：

```dart
final responseStream = response.data.stream as Stream<List<int>>;
await for (final chunk in responseStream.transform(utf8.decoder)) {
```

改为：

```dart
final responseStream = (response.data.stream as Stream<Uint8List>)
    .cast<List<int>>();
await for (final chunk in responseStream.transform(utf8.decoder)) {
```

需要增补 `import 'dart:typed_data';`。

`.cast<List<int>>()` 会创建一个新的包装 `Stream<List<int>>`，运行时类型正确匹配 `Utf8Decoder` 要求的 `StreamTransformer<List<int>, String>`，不再触发类型错误。

### 影响范围
- AI 对话面板流式回复（`chatStream`）修复
- 不影响非流式请求（`chat` 方法）
- 不影响其他配置了的供应商（所有供应商走同一个 `chatStream` 逻辑）

### 单元测试建议
- 测试 `chatStream` 在正常 SSE 响应下能正确解析 `data: {...}` 行
- 测试 `[DONE]` 终止标记能正确结束流
- 测试 HTTP 非 200 响应能抛出 `AiException`

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

# 运行 DAO 测试
flutter test test/daos/

# 运行全部测试
flutter test
```

**前置条件**: Flutter 3.27+, Dart 3.6+, Visual Studio 2022 (含 C++ 桌面工作负载), Windows 10/11 64-bit
