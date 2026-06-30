# DeskTips

macOS 桌面悬浮待办工具 — 半透明置顶显示，不影响日常使用。

灵感来自 QQ 音乐桌面歌词和 Snipaste 的悬浮窗交互方式。

## 功能特性

### 悬浮窗
- **双显示模式**：玻璃模式（`.thickMaterial` 系统材质）和透明模式（`.ultraThinMaterial`），各自独立强度控制
- **锁定/编辑双模式**：锁定模式防误触（全窗口拖拽），编辑模式支持完整操作
- **原生拖拽**：AppKit `performDrag` 实现，丝滑跟手，鼠标悬停手型反馈 + 高亮效果
- **可自定义标题**：双击编辑，自动持久化保存
- **待办管理**：添加、完成、删除，支持 `[...]` 更多菜单操作
- **窗口位置记忆**：重启后自动恢复上次位置和显示设置

### 主窗口
- **三标签页**：待办、历史、设置
- **待办**：完整 CRUD、拖拽排序、双击编辑标题
- **历史**：已完成事项按日期分组（今天/昨天/具体日期），支持恢复和永久删除
- **设置**：悬浮窗模式切换、强度控制、开机自启动（`SMAppService`）、版本信息

### 菜单栏
- 顶部状态栏图标，点击弹出快捷面板
- 快速添加待办、切换悬浮窗、打开主窗口、退出
- 支持键盘快捷键（Cmd+C/V/X/A/Z）

### 技术特点
- 菜单栏应用（无 Dock 图标），主窗口打开时临时显示
- Liquid Glass / macOS 26 原生材质
- Swift 6 严格并发
- `UserDefaults` + `JSONEncoder` 数据持久化
- 单实例 `TodoStore` 全局共享

## 技术栈

- **语言**：Swift 6
- **UI**：SwiftUI + AppKit（`NSHostingController` 桥接）
- **平台**：macOS 26+
- **架构**：AppKit 生命周期（`AppDelegate`）+ SwiftUI 内容渲染
- **数据层**：本地 SPM 包 `DeskTipsCore`（`TodoStore` + `SettingsStore`）
- **构建**：Xcode + xcodebuild

## 项目结构

```
desk_tips/
├── DeskTips.xcodeproj/              # Xcode 项目
├── DeskTips/                        # App 目标
│   ├── App/
│   │   ├── main.swift               # 入口 + 隐藏 Edit 菜单
│   │   ├── AppDelegate.swift        # 生命周期协调
│   │   ├── StatusBarController.swift    # 菜单栏图标 + 弹窗
│   │   ├── OverlayWindowController.swift # 悬浮窗管理
│   │   └── MainWindowController.swift   # 主窗口管理
│   ├── Views/
│   │   ├── OverlayContentView.swift     # 悬浮窗 UI（锁定/编辑双模式）
│   │   ├── SettingsView.swift           # 菜单栏弹窗
│   │   ├── MainTabView.swift            # 主窗口 TabView
│   │   ├── TodoListView.swift           # 待办列表
│   │   ├── HistoryView.swift            # 历史按日期
│   │   └── MainSettingsView.swift       # 设置页
│   └── Resources/
├── DeskTipsCore/                    # 纯 Swift 数据层（SPM 包）
│   ├── Sources/DeskTipsCore/
│   │   ├── Models/
│   │   │   ├── TodoItem.swift       # 数据模型
│   │   │   ├── TodoStore.swift      # 待办存储 + 历史归档
│   │   │   ├── OverlaySettings.swift    # 悬浮窗设置模型
│   │   │   └── SettingsStore.swift      # 设置存储
│   │   └── Protocols/
│   │       ├── PersistenceService.swift     # 待办持久化
│   │       └── SettingsPersistence.swift    # 设置持久化
│   └── Tests/                       # 27 个单元测试
└── README.md
```

## 构建与运行

```bash
# 克隆
git clone https://github.com/hhcme/desk_tips.git
cd desk_tips

# 构建核心包测试
cd DeskTipsCore && swift test

# 构建 App
cd ..
xcodebuild -project DeskTips.xcodeproj -scheme DeskTips -configuration Debug build

# 运行
open ~/Library/Developer/Xcode/DerivedData/DeskTips-*/Build/Products/Debug/DeskTips.app
```

## 截图

> 欢迎补充截图

## 系统要求

- macOS 26 (Tahoe) 或更高版本
- Xcode 26+
- Swift 6.3+

## License

MIT
