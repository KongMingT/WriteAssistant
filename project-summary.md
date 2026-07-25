# WriterAssistant 项目总结

> 基于 Flutter 的 AI 辅助中文网文写作工具，目标平台：Windows（主力）/ Android（规划中）
>
> GitHub: https://github.com/KongMingT/WriteAssistant.git

---

## 一、项目概览

WriterAssistant 是一款面向中国网络小说作者的 AI 辅助桌面写作软件。采用三栏布局（目录树 | 编辑器 | AI 面板），集成多种 AI 模型接口，提供从大纲生成、正文扩写、角色管理到书籍分析的全流程辅助功能。

| 维度 | 内容 |
|------|------|
| **框架** | Flutter 3.27.4, Dart 3.6.2 |
| **状态管理** | Riverpod (flutter_riverpod ^2.5.0) |
| **数据库** | drift ^2.16.0 (SQLite ORM, 代码生成) |
| **AI 接口** | Dio ^5.4.0, 支持 4 家供应商 |
| **构建** | CMake + Visual Studio 2022 |
| **许可证** | MIT |
| **当前版本** | 1.0.0+1 |
| **完成度** | 核心功能基本可用，约 60% |

---

## 二、技术架构

### 2.1 框架与语言

```
Flutter 3.27.4 + Dart 3.6.2
    └── Windows 10/11 64-bit (Win32)
    └── Android (规划中)
    └── Web (次要目标)
```

### 2.2 状态管理（Riverpod）

| Provider 类型 | 用途 |
|---------------|------|
| `StateProvider` | 选中的章节、选中的书籍、写作状态、树刷新信号 |
| `FutureProvider` | AI 配置异步加载 |
| `StateNotifierProvider` | 主题模式、字号、字体族 |
| `Provider` | 依赖注入（数据库、DAO） |

### 2.3 数据层

- **ORM**: drift (SQLite)，代码生成 `database.g.dart` (~8000+ 行)
- **安全存储**: flutter_secure_storage（API Key、主题/字体偏好）
- **路径管理**: path_provider + path

#### 数据库表结构（9 张表）

| 表 | 说明 |
|----|------|
| `books` | 书籍（标题、作者、简介） |
| `volumes` | 卷（书名: 第N卷, 关联 book） |
| `chapters` | 章节（标题、正文内容、字数、关联 volume） |
| `characters` | 角色（名称、角色类型、性别、年龄、背景等，关联 book） |
| `character_relations` | 角色间关系（源角色、目标角色、关系描述） |
| `outline_nodes` | 大纲节点（关联 chapter） |
| `plot_lines` | 剧情线（关联 book） |
| `plot_nodes` | 剧情节点（关联 plot_line） |
| `writing_sessions` | 写作时段（开始/结束时间、字数、关联 chapter） |

### 2.4 AI 集成

| 供应商 | API 端点 | 默认模型 |
|--------|----------|----------|
| DeepSeek | `api.deepseek.com/v1` | deepseek-chat |
| 通义千问 | `dashscope.aliyuncs.com/compatible-mode/v1` | qwen-plus |
| OpenAI | `api.openai.com/v1` | gpt-4o-mini |
| 月之暗面 | `api.moonshot.cn/v1` | moonshot-v1-8k |

- 温度固定 0.8，max_tokens 4096
- API Key 通过 `flutter_secure_storage` 加密存储
- 支持连接测试

### 2.5 目录结构

```
lib/
├── main.dart                          # 入口, ProviderScope 包装
├── app.dart                           # MaterialApp 根组件, 主题配置
├── core/
│   ├── ai/
│   │   ├── ai_client.dart             # Dio 封装的 AI HTTP 客户端
│   │   ├── models/ai_model_config.dart # AI 供应商枚举、安全存储、Riverpod providers
│   │   └── prompts/prompts.dart       # 5 套 AI 提示词模板
│   ├── database/
│   │   ├── database.dart              # AppDatabase 定义、连接配置
│   │   ├── database.g.dart            # Drift 生成代码
│   │   ├── providers.dart             # DAO 的 Riverpod Provider
│   │   ├── tables/                    # 9 张表的定义文件
│   │   └── daos/                      # 7 个 DAO 类
│   ├── services/
│   │   └── txt_import_service.dart    # TXT 导入服务（编码检测、章节拆分）
│   └── utils/
│       └── id_generator.dart          # 基于时间戳的 ID 生成器
├── features/
│   ├── book_analysis/
│   │   └── book_analysis_screen.dart  # AI 拆书分析页面
│   ├── character/
│   │   └── character_list_screen.dart # 角色列表与编辑
│   ├── settings/
│   │   └── settings_screen.dart       # AI 供应商配置页面
│   └── workspace/
│       ├── ai_panel/ai_panel.dart     # AI 聊天面板（快捷操作、对话气泡）
│       ├── editor/chapter_editor.dart # 富文本编辑器（含工具栏）
│       ├── models/selection_state.dart# 选中状态的 Riverpod 定义
│       ├── sidebar/chapter_tree.dart  # 书籍/卷/章节树形目录
│       └── workspace_screen.dart      # 三栏布局编排
└── shared/
    ├── themes/theme_provider.dart     # 主题模式、字体设置 Provider
    └── widgets/status_bar.dart        # 底部状态栏（字数、速度、主题切换）
```

---

## 三、已实现功能

### 3.1 核心编辑体验
- **三栏可拖拽布局**：左侧目录 | 中间编辑器 | 右侧 AI 面板，面板可折叠
- **自动保存**：正文 3 秒防抖、标题 500ms 防抖写入 SQLite
- **中文排版优化**：Tab 插入全角空格首行缩进，回车自动继承前导缩进
- **字体/字号调节**：4 种中文字体（宋体、楷体、黑体、微软雅黑），12-32px
- **底部状态栏**：实时字数、写作速度（字符/小时）、写作时长、一键日/夜间模式

### 3.2 书籍管理
- **书籍 → 卷 → 章节** 三级树形结构
- **右键菜单**：新建、重命名、删除（带确认对话框）
- **自动命名**：新建时自动生成 "第一卷"/"第一章" 等

### 3.3 TXT 导入
- 文件选择器导入 `.txt` 文件
- 自动检测编码（UTF-8 BOM → UTF-8 → GBK）
- 正则拆分章节（`第[一二三四五六七八九十百千万0-9]+[章回节部]`）
- 导入自动创建新书

### 3.4 AI 辅助面板
- **对话式交互**：用户消息右对齐，AI 回复左对齐
- **5 种快捷操作**：
  - 大纲生成（生成 10-20 章大纲）
  - 细节扩写（大纲 → 3000-4000 字正文）
  - 起名助手（角色/地名生成）
  - 卡文助手（3-5 个剧情建议）
  - 书籍分析（角色关系、情节结构、写作技法）
- **一键复制** AI 回复内容
- **清空对话** 按钮

### 3.5 角色管理
- 角色列表视图，标注角色类型标签（主角/反派/配角）
- CRUD 操作弹窗
- 字段：姓名（必填）、角色类型、性别、年龄、性格、背景、外貌、备注
- 自动关联当前书籍

### 3.6 拆书分析（外部分析模式）
- 导入外部 TXT 用于 AI 分析
- 支持 "导入为书籍"
- 分析结果一键复制

### 3.7 主题系统
- 浅色/深色模式（安全存储持久化）
- Material 3 设计
- 种子颜色靛蓝 `#6366F1`

### 3.8 写作时段追踪
- 记录每次写作时段（开始/结束时间、字数）
- 用于实时写作速度计算

---

## 四、当前问题与风险

### 4.1 功能缺陷

| 问题 | 严重度 | 说明 |
|------|--------|------|
| **AI 流式未实现** | 高 | `AiClient.chat()` 接受 `stream` 参数但从未使用，大规模响应等待完整返回 |
| **无 API 重试机制** | 中 | 单次网络失败即向用户展示错误 |
| **ID 生成器碰撞风险** | 中 | `generateId()` 使用毫秒+微秒模 100000，同一微秒内可能重复 |
| **聊天历史清除问题** | 中 | 清除按钮仅清空内存列表，不重置 API 上下文 |
| **数据库无迁移策略** | 高 | `schemaVersion=1`，`onUpgrade` 为空，后续改表将破坏现有数据 |
| **字数量统计效率低** | 中 | `getBookWordCount()` 遍历所有卷/章节加载到内存，未使用 SQL SUM |
| **TXT 章节拆分覆盖不全** | 低 | 正则可能遗漏 "Chapter 1"、"序章"、"尾声" 等格式 |

### 4.2 代码质量

| 问题 | 说明 |
|------|------|
| **无单元测试** | 仅 1 个冒烟测试，7 个 DAO 完全无测试覆盖 |
| **无日志系统** | `avoid_print` lint 启用，但无正式日志框架 |
| **硬编码字符串** | 提示词、UI 标签、错误消息未集中管理 |
| **UI 层耦合数据库** | `ChapterTree`、`WorkspaceScreen` 绕过 Service 层直接调用 DAO |
| **空目录残留** | `features/book/`、`chapter/`、`outline/` 为空 |
| **仓库杂物** | `vs_community.exe`（二进制文件）、`push_log.txt` 等已入库 |

### 4.3 用户体验

| 问题 | 说明 |
|------|------|
| **无键盘快捷键** | 无 Ctrl+S / Ctrl+N 等常用快捷键 |
| **编辑器缺少加载状态** | 选中章节后无 loading 指示 |
| **主题切换闪烁** | `themeModeProvider` 异步加载安全存储，启动可能有默认主题闪烁 |
| **无导出功能** | 不支持 TXT 导出 |
| **字符数限制 8000** | `_startAnalysis()` 截断内容至 8000 字符，可能丢失分析上下文 |

---

## 五、优化方向

### 5.1 立即优化（高优先级）

1. **实现 AI 流式响应** — 使用 Dio `responseStream` + SSE 解析，实现打字机效果
2. **添加 API 重试机制** — Dio 拦截器指数退避重试 2-3 次
3. **替换 ID 生成器** — 使用 `uuid` 包或数据库自增主键
4. **建立数据库迁移** — 实现 `onUpgrade` 版本化迁移
5. **编写单元测试** — 覆盖 7 个 DAO 的核心 CRUD 逻辑
6. **清理仓库** — 删除 `vs_community.exe`、`push_log.txt`、`push_log2.txt`

### 5.2 中期优化

7. **添加日志服务** — 使用 `logging` 包替代 `print`
8. **提取字符串资源** — 统一管理 UI 文本，支持后续 i18n
9. **使用 `hydrated_riverpod`** — 自动状态持久化，减少手动安全存储写入
10. **章节懒加载** — 大型书籍分页加载目录树
11. **添加键盘快捷键** — Ctrl+S 保存、Ctrl+N 新建章节等
12. **实现 TXT 导出** — 与现有导入对应的导出功能

### 5.3 架构优化

13. **引入 Service 层** — 解耦 UI 与 DAO，DAO 不直接暴露给 Widget
14. **完成模块拆分** — 填充 `features/book/`、`chapter/`、`outline/` 目录
15. **优化字数量统计** — 使用 SQL `SUM(LENGTH(content))` 替代全表加载
16. **AI 上下文管理** — 重置对话时清空上下文，避免累积 token 超限
17. **添加 Editor Loading** — 章节选中但未加载时展示 loading 指示器
18. **主题预加载** — 同步读取偏好主题，消除启动闪烁

---

## 六、构建与运行

```bash
# 生成 drift 数据库代码
dart run build_runner build

# 构建 Windows 桌面版
flutter build windows

# 运行
flutter run -d windows
```

**前置条件**：
- Flutter 3.27+ SDK
- Visual Studio 2022（含 C++ 桌面工作负载）
- 中文字体支持

---

## 七、项目状态总结

| 维度 | 评价 |
|------|------|
| **架构设计** | 良好，Riverpod + drift 组合合理，分层清晰 |
| **核心功能** | 编辑器、目录树、AI 面板基本可用 |
| **代码质量** | 中上，命名规范、空安全到位，但测试严重缺失 |
| **AI 集成** | 覆盖 4 家供应商，但缺少流式体验和重试机制 |
| **用户体验** | 基础可用，缺少快捷键、loading 状态、导出等 |
| **可维护性** | 中等，数据库迁移、字符串管理、日志等方面需要加强 |
| **完成度** | 约 60%，核心路径通，边缘功能和完善工作较多 |
