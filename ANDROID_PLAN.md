# Android 端适配规划

> Flutter 原生支持 Android，但当前代码以 Windows 桌面为主，需针对性适配移动端交互与能力差异。

---

## ✅ 已就绪（无需改动）

- **依赖兼容**：所有依赖（drift/sqlite3_flutter_libs/path_provider/file_picker/flutter_secure_storage/dio/archive/uuid/intl）均支持 Android
- **数据库路径**：`getApplicationDocumentsDirectory()` 跨平台通用，SQLite 文件直用
- **AI 网络请求**：Dio + SSE 流式在 Android 同桌面表现一致
- **资源文件**：字体/图标/主题通过 `flutter:` assets 配置即可复用

---

## ⚠️ 需适配项（按优先级）

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

---

## 🛠 配置清单

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

---

## 📦 构建产物对比

| 平台 | 命令 | 产物 | 备注 |
|------|------|------|------|
| Windows | `flutter build windows --release` | `.exe` + DLL | 需 VS2022 |
| **Android** | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` | 可直接安装/分发 |
| Android | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` | Play Console 上传必需 |

---

## 🔄 迭代建议

| 阶段 | 目标 | 关键交付 |
|------|------|----------|
| A1 | **最小可用** | 编译通过、数据库读写、AI 对话、基础编辑、单栏导航、APK 打包 |
| A2 | **体验对齐** | 响应式布局、工具栏适配、文件导入导出(分享面板)、长按菜单、虚拟键盘适配 |
| A3 | **原生感** | 启动图/闪屏、推送通知(写作提醒)、桌面快捷方式、生物识别锁应用、横屏/平板优化 |
| A4 | **发布就绪** | Play Console 上架、应用内更新、崩溃上报、混淆/加固、隐私政策合规 |

---

## 📌 适配原则

1. **单代码库、多端响应式** —— `LayoutBuilder`/`MediaQuery` 断点复用，不分仓
2. **桌面优先不倒退** —— 移动端适配不破坏现有桌面体验
3. **能力降级优雅** —— 移动端无法实现的功能（如多窗口拖拽）提供替代方案而非隐藏
4. **性能兜底** —— 低端机型内存/CPU 限制下大章节/大纲仍可流畅编辑

---

## 🔁 多端功能同步要求

> **重要**：单代码库双端运行，**新增/修改桌面端功能时，必须同步评估 Android 端体验**。

| 场景 | 同步动作 |
|------|----------|
| 新增编辑器工具栏按钮 | Android 端工具栏同步增减/折叠菜单适配 |
| 新增快捷键 | Android 端补充对应图标按钮/手势/语音触发 |
| 新增右键/悬浮菜单 | Android 端改为长按/点击展开/BottomSheet |
| 新增拖拽交互 | Android 端改为编辑模式+箭头/长按手柄 |
| 新增文件导入导出 | Android 端用 `share_plus` 分享面板替代目录选择 |
| 修改三栏/多栏布局 | Android 端按断点自动切换单栏/双栏/三栏 |
| 新增设置项 | Android 端设置页同步显示，响应式布局 |
| 性能优化（大章节/大纲） | 移动端阈值更低（建议 100k 字符预警），虚拟化渲染优先 |

**检查清单（每次 PR 前自查）**：
- [ ] Windows 编译通过、功能正常
- [ ] Android 编译通过、功能正常（或已有替代方案）
- [ ] 响应式断点测试：<600dp / 600-900dp / >900dp
- [ ] 虚拟键盘遮挡测试
- [ ] 文件导入导出在 Android 可用（分享面板/下载目录）
- [ ] 无桌面专用 API 残留（`HardwareKeyboard`、`onSecondaryTapDown` 等需守卫/替代）

**CI/CD 建议**：
```yaml
# .github/workflows/android.yml 关键步骤
- flutter build apk --debug        # 编译验证
- flutter test                      # 单元测试
- flutter drive --target=test_driver/app.dart  # 集成测试（可选）
```

---

*关联文档：[AGENTS.md](AGENTS.md) 总纲 · [开发规划](AGENTS.md#-开发规划用户视角的竞品差距与功能增强)*