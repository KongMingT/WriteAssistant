# WriterAssistant - Agent Guide

## 项目概览

WriterAssistant 是一款**面向中文网文作者的 AI 辅助写作桌面应用**，使用 Flutter 构建，目标平台为 Windows。

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
│   │   ├── database.g.dart            # Drift 生成代码 (~8000行)
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
- **注意**: 当前 `schemaVersion=1`，`onUpgrade` 为空，**禁止直接改表** — 必须先添加迁移逻辑

---

## 最近改动 (会话2)

| 改动 | 说明 |
|------|------|
| 回车缩进重写 | 拦截 Enter 键手动插入 `\n` + 前导全角空格，不再依赖 `Future.microtask`，Shift+Enter 跳过缩进 |
| 角色管理 -> 弹窗 | `character_sheet.dart` 新建，工作区内 `showModalBottomSheet` 展示角色列表，显示当前书名 |
| 书籍选择首页 | `book_selection_screen.dart` 新建，卡片网格展示所有书籍，点击进入工作区 |
| 侧边栏重构 | `chapter_tree.dart` 接受 `bookId`，只显示该书的卷/章节，删除书籍层级管理代码 |
| 工作区重构 | `workspace_screen.dart` 接受 `bookId` 参数，AppBar 显示书名 + 返回按钮 |
| 首页路由 | `app.dart` home 改为 `BookSelectionScreen` |
| 文件清理 | `workspace_screen.dart` 移除导入 TXT 和新建书籍逻辑（移至首页） |

---

## 待完善 & 注意事项

### 高优先级
1. **数据库迁移** — `schemaVersion=1`，`onUpgrade` 为空。任何表结构变更必须先实现迁移逻辑，否则用户数据会丢失。
2. **单元测试** — 目前仅 1 个冒烟测试。7 个 DAO 完全无测试覆盖，建议优先覆盖。
3. **AI 面板滚动闪烁** — 流式响应时 `_scrollToBottom` 高频触发，可能造成滚动条抖动。可增加防抖或只在末尾追加时滚动。

### 中优先级
4. **大章节性能** — `chapters.content` 为 `TextColumn` 无大小限制，长篇章节可能导致内存问题。可考虑分页加载或惰性加载。
5. **导入格式增强** — 当前 TXT 导入正则 `(第[一二三四五六七八九十百千万０-９0-9]+[章回节部])` 会遗漏 "序章"、"尾声"、"Chapter 1" 等格式。
6. **搜索功能** — 缺少全局搜索/替换，对大型作品影响较大。
7. **字数统计优化** — `BookDao.getBookWordCount()` 全表遍历，应改为 SQL `SUM` 查询。
8. **书籍删除级联** — `book_dao.dart` 的 `deleteBook` 不会级联删除卷和章节，需要手动处理。

### 低优先级
9. **多语言支持** — 所有 UI 字符串硬编码为中文，未做 i18n。
10. **日志系统** — 无正式日志框架，`avoid_print` lint 开启但无处输出。
11. **自动更新** — 无版本检测/更新机制。
12. **云同步** — 无云端备份/同步功能。

### 已知限制
- Windows 独占（Android 和 Web 有配置但未测试）
- AI 提示词固定为中文网文场景
- 章纲目前仅支持单层节点（`parentId` 字段存在但未实现层级 UI）
- `flutter_secure_storage` 在 Web 上不可用（但 Web 不是目标平台）

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
```

**前置条件**: Flutter 3.27+, Dart 3.6+, Visual Studio 2022 (含 C++ 桌面工作负载), Windows 10/11 64-bit
