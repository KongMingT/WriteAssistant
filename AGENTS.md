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
- **注意**: `schemaVersion=2`，`onUpgrade` 已实现 v1→v2 迁移逻辑（12 列新增）。改表时必须同步更新 `schemaVersion` 和 `onUpgrade`

---

## 最近改动

| 改动 | 说明 |
|------|------|
| DAO 单元测试 | 7 个 DAO 共 34 个测试用例全部通过。`AppDatabase` 重构为接受可选 `QueryExecutor` 以支持 `NativeDatabase.memory()` 测试。新增 `sqlite3` dev 依赖 |
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
