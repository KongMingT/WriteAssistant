# WriterAssistant

<div align="center">
  <p><strong>面向网文作者的 AI 辅助写作桌面应用</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.27-blue?logo=flutter" alt="Flutter 3.27">
    <img src="https://img.shields.io/badge/Platform-Windows-blueviolet?logo=windows" alt="Platform Windows">
    <img src="https://img.shields.io/badge/License-MIT-green" alt="License MIT">
  </p>
</div>

## 📖 简介

WriterAssistant 是一款专为网络小说作者设计的 AI 辅助写作桌面工具。采用三栏式布局（目录 | 编辑器 | AI 面板），提供沉浸式写作体验。

**核心功能：**
- ✍️ 富文本编辑器（自动保存、字体切换、缩进排版）
- 📂 书籍/分卷/章节树形管理（支持右键菜单）
- 🤖 AI 辅助（大纲生成、细纲扩写、起名、卡文求助）
- 📊 拆书分析（导入 TXT → AI 分析人物关系与剧情结构）
- 👥 角色管理（角色卡片、关系追踪）
- 🌙 深色/浅色主题切换

## 🚀 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| Flutter | 3.27.4+ |
| Dart | 3.6.2+ |
| Windows | 10/11（64位） |
| Visual Studio | 2022（含 C++ 桌面开发组件） |

### 构建运行

```bash
# 克隆仓库
git clone https://github.com/KongMingT/WriteAssistant.git
cd WriteAssistant

# 安装依赖
flutter pub get

# 生成数据库代码
dart run build_runner build --delete-conflicting-outputs

# 运行（调试模式）
flutter run -d windows

# 构建可执行文件
flutter build windows --debug
```

构建产物位于：`build\windows\x64\runner\Debug\writer_assistant.exe`

### 常见问题

**Q: 构建报错 `win32` 版本冲突？**
A: 运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成。

**Q: 无法连接 AI API？**
A: 首次使用需在 设置 → AI 模型配置 中填写 API Key（支持 DeepSeek、通义千问、Moonshot、OpenAI）。

## 🎯 使用指南

### 工作区布局

```
┌─────────────┬──────────────────────┬──────────────┐
│   目录区     │      编辑区           │   AI 面板    │
│  (可折叠)    │ 工具栏              │  (可折叠)     │
│             │ 章节标题             │              │
│  书籍        │ 正文编辑区           │  快捷操作    │
│  ├ 分卷1    │  (自动保存)          │  对话记录    │
│  │ ├ 第1章  │                     │  输入框      │
│  │ ├ 第2章  │                     │              │
│  └ 分卷2    │                     │              │
├─────────────┴──────────────────────┴──────────────┤
│  状态栏：字数  |  速度  |  本次写作时间  |  🌙     │
└──────────────────────────────────────────────────┘
```

### 目录区（左侧）
- **右键菜单**：书籍/分卷/章节上右键可重命名、删除、新建
- **点击章节**：在编辑区打开对应章节
- **➕ 按钮**：新建书籍、分卷、章节

### 编辑区（中间）
- **工具栏**：字体选择（宋体/楷体/黑体/微软雅黑）、字号加减、缩进加减、自动排版
- **Tab 键**：插入两个全角空格缩进
- **Enter 键**：自动继承上一行缩进
- **标题栏**：修改后自动保存，目录区实时同步
- **内容**：3 秒防抖自动保存

### AI 面板（右侧）
- **快捷操作**：大纲梳理、细纲扩写、起名、卡文助手
- **对话模式**：输入问题直接与 AI 交流
- **复制结果**：AI 回复底部点击复制按钮，粘贴到编辑器

### 底部状态栏
- 实时显示当前字数、码字速度（字/时）、本次写作时长
- 右下角一键切换深色/浅色主题

### 导入 TXT
点击顶部 **📄 导入 TXT** 按钮：
1. 自动检测文件编码（UTF-8 / GBK）
2. 按 `第X章` 格式自动拆分章节
3. 导入为新的书籍项目

### 角色管理
点击顶部 **👥 人物管理**：
- 创建/编辑角色卡片
- 设置角色类型（主角/反派/配角）
- 填写性格、背景、外貌等详细信息

### 拆书分析
点击顶部 **📖 拆书分析**：
1. 导入任意 TXT 小说
2. AI 自动分析人物关系和剧情结构
3. 可一键导入为书籍项目

### AI 模型配置
点击顶部 **⚙️ 设置**：
- 选择 AI 提供商（DeepSeek / 通义千问 / Moonshot / OpenAI）
- 填写并加密保存 API Key（本地存储，不上传）
- 支持测试连接验证配置

## 🏗️ 项目结构

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # 根组件（主题配置）
├── core/
│   ├── database/                  # SQLite 数据库（drift）
│   │   ├── database.dart          # 数据库初始化
│   │   ├── database.g.dart        # 代码生成
│   │   ├── tables/                # 表定义（9张表）
│   │   ├── daos/                  # 数据访问对象（7个DAO）
│   │   └── providers.dart         # Riverpod 提供者
│   ├── ai/                        # AI 大模型接入
│   │   ├── ai_client.dart         # HTTP 客户端（Dio）
│   │   ├── models/                # 模型/配置管理
│   │   └── prompts/               # 提示词模板
│   ├── services/                  # 业务服务
│   │   └── txt_import_service.dart # TXT 导入服务
│   └── utils/                     # 工具函数
├── features/
│   ├── workspace/                 # 主工作区
│   │   ├── workspace_screen.dart  # 三栏布局
│   │   ├── editor/                # 编辑器
│   │   ├── sidebar/               # 目录树
│   │   ├── ai_panel/              # AI 面板
│   │   └── models/                # 状态模型
│   ├── settings/                  # 设置页面
│   ├── character/                 # 角色管理
│   └── book_analysis/             # 拆书分析
└── shared/
    ├── themes/                    # 主题配置
    └── widgets/                   # 共享组件
```

## 🧰 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.27 (Dart 3.6) |
| 桌面 | Windows (Win32) |
| 存储 | drift (SQLite) |
| 状态管理 | Riverpod |
| AI 接入 | Dio (HTTP) |
| 安全存储 | flutter_secure_storage |
| 文件导入 | file_picker |

## 📄 开源协议

本项目基于 MIT 协议开源。

### AI 模型配置

1. 点击右上角 ⚙️ **设置** 按钮
2. 选择一个 AI 供应商（DeepSeek / 通义千问 / OpenAI / Moonshot）
3. 填入你的 API Key 并保存
4. 点击「测试连接」验证配置是否生效

> **API Key 获取地址：**
> - [DeepSeek](https://platform.deepseek.com/api_keys)
> - [通义千问](https://dashscope.console.aliyun.com/apiKey)
> - [Moonshot](https://platform.moonshot.cn/console/api-keys)

---

## 📂 项目结构

```
writer_assistant/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── app.dart                           # MaterialApp 根组件
│   │
│   ├── core/                              # 核心基础设施
│   │   ├── database/                      # 数据层 (drift/SQLite)
│   │   │   ├── database.dart              # 数据库定义 + 9张表
│   │   │   ├── providers.dart             # Riverpod Provider
│   │   │   ├── tables/                    # 表定义（书籍/卷/章节/大纲/角色等）
│   │   │   └── daos/                      # 数据访问对象 (7个 DAO)
│   │   ├── ai/                            # AI 大模型接入
│   │   │   ├── ai_client.dart             # HTTP 客户端 (Dio)
│   │   │   ├── models/                    # 供应商定义 + 安全存储
│   │   │   └── prompts/                   # 提示词模板
│   │   ├── services/                      # 业务服务（TXT导入等）
│   │   └── utils/                         # 工具（ID生成器）
│   │
│   ├── features/                          # 功能模块
│   │   ├── workspace/                     # 工作区（三栏布局）
│   │   │   ├── workspace_screen.dart      # 主界面
│   │   │   ├── sidebar/chapter_tree.dart  # 目录树
│   │   │   ├── editor/chapter_editor.dart # 编辑器（含工具栏）
│   │   │   ├── ai_panel/ai_panel.dart     # AI 对话面板
│   │   │   └── models/selection_state.dart
│   │   ├── character/                     # 角色管理
│   │   ├── book_analysis/                 # 拆书分析
│   │   └── settings/                      # 设置页
│   │
│   └── shared/                            # 共享
│       ├── widgets/status_bar.dart        # 底部状态栏
│       └── themes/theme_provider.dart     # 主题/字体 Provider
│
├── docs/                                  # 文档
│   ├── spec-v1.md                         # 需求规格
│   ├── architecture.md                    # 架构说明
│   ├── project-structure.md               # 项目结构
│   └── remaining-tasks.md                 # 待办事项
│
└── pubspec.yaml                           # 依赖配置
```

---

## 🛠 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **框架** | Flutter 3.27 | 跨平台 UI 框架 |
| **语言** | Dart 3.6 | 类型安全的编程语言 |
| **本地存储** | drift (SQLite) | 类型安全的 ORM，9 张表 |
| **状态管理** | Riverpod | 响应式状态管理 |
| **AI 接入** | Dio (HTTP) | REST API 调用大模型 |
| **安全存储** | flutter_secure_storage | API Key 加密存储 |
| **文件选择** | file_picker | TXT 文件导入 |

---

## 📄 开源协议

本项目基于 MIT 协议开源。

---

## 🙏 致谢

- 感谢所有网文作者的创作热情，这是本项目的初心
- [Flutter](https://flutter.dev/) — 优秀的跨平台 UI 框架
- [drift](https://drift.simonbinder.eu/) — 强大的 Dart SQLite ORM
- [Riverpod](https://riverpod.dev/) — 优雅的状态管理方案
