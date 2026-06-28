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
- ✍️ **编辑器** — 自动保存、字体/字号切换、首行缩进排版
- 📂 **目录管理** — 书籍→分卷→章节树形结构，右键菜单操作
- 🤖 **AI 辅助** — 大纲生成、细纲扩写、智能起名、卡文求助
- 📊 **拆书分析** — 导入 TXT → AI 分析人物关系与剧情结构
- 👥 **角色管理** — 角色卡片，记录类型/性格/背景等
- 🌙 **主题切换** — 右下角一键切换深色/浅色

---

## 🚀 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| Flutter | 3.27.4+ |
| Dart | 3.6.2+ |
| Windows | 10/11（64位） |
| Visual Studio | 2022（含 C++ 桌面开发工作负载） |

### 构建运行

```bash
git clone https://github.com/KongMingT/WriteAssistant.git
cd WriteAssistant
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows        # 调试运行
flutter build windows --debug # 构建 exe
```

构建产物：`build\windows\x64\runner\Debug\writer_assistant.exe`

### 常见问题

> **Q: 构建报错 `win32` 版本冲突？**  
> A: 运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成。
>
> **Q: 无法连接 AI API？**  
> A: 首次使用需在 ⚙️ **设置** 中填写 API Key。

---

## 🎯 使用指南

```
┌────────────┬──────────────────────┬─────────────┐
│   目录区    │      编辑区          │   AI 面板   │
│  (可折叠)   │ 工具栏 ↑ 标题       │  (可折叠)    │
│  书籍       │ 正文编辑区           │  快捷操作    │
│  ├ 分卷1   │  (自动保存)          │  对话记录    │
│  │ ├ 第1章 │                     │  输入框      │
│  └ 分卷2   │                     │              │
├────────────┴──────────────────────┴─────────────┤
│  状态栏：字数  |  速度  |  本次写作时间  |  🌙   │
└─────────────────────────────────────────────────┘
```

### 三区操作

| 区域 | 功能 |
|------|------|
| **目录区**（左侧） | 右键菜单重命名/删除/新建；点击章节打开编辑；➕ 按钮新建书籍/分卷/章节 |
| **编辑区**（中间） | 工具栏设置字体（宋体/楷体/黑体/微软雅黑）、字号、缩进；**Tab** 插入缩进、**Enter** 自动继承缩进；标题与内容均自动保存 |
| **AI 面板**（右侧） | 快捷操作（大纲/扩写/起名/卡文）；对话模式提问；复制 AI 回复到剪贴板 |

### 特色功能

- **导入 TXT** — 点击顶部 📄 按钮，自动检测编码（UTF-8/GBK），按章节拆分并导入为新书
- **角色管理** — 点击顶部 👥 按钮，创建角色卡片，设置类型（主角/反派/配角）与详细信息
- **拆书分析** — 点击顶部 📖 按钮，导入小说让 AI 分析；分析结果可一键导入为项目
- **AI 配置** — 点击顶部 ⚙️ 按钮，选择供应商（DeepSeek / 通义千问 / Moonshot / OpenAI），填写 API Key 并测试连接

  > **API Key 获取：** [DeepSeek](https://platform.deepseek.com/api_keys) · [通义千问](https://dashscope.console.aliyun.com/apiKey) · [Moonshot](https://platform.moonshot.cn/console/api-keys)

---

## 🏗️ 项目结构

```
lib/
├── main.dart                      # 入口
├── app.dart                       # 根组件（主题）
├── core/
│   ├── database/                  # SQLite（drift）：9张表 + 7个DAO + Provider
│   ├── ai/                        # AI 接入：Dio 客户端 + 模型配置 + 提示词
│   ├── services/                  # 业务服务（TXT导入）
│   └── utils/                     # 工具函数
├── features/
│   ├── workspace/                 # 主工作区（三栏布局 + 编辑器 + 目录树 + AI面板）
│   ├── settings/                  # 设置页
│   ├── character/                 # 角色管理
│   └── book_analysis/             # 拆书分析
└── shared/
    ├── themes/                    # 主题/字体配置
    └── widgets/                   # 状态栏组件
```

---

## 🧰 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.27 (Dart 3.6) |
| 桌面 | Windows (Win32) |
| 存储 | drift (SQLite) |
| 状态管理 | Riverpod |
| AI 接入 | Dio (HTTP) |
| 安全存储 | flutter_secure_storage |
| 文件选择 | file_picker |

---

## 📄 开源协议

本项目基于 MIT 协议开源。
