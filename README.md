# DeskTips

macOS 桌面悬浮待办工具 — 半透明置顶显示，不影响日常使用。

灵感来自 QQ 音乐桌面歌词和 Snipaste 的悬浮窗交互方式。

## 功能特性

### 悬浮窗
- **双显示模式**：玻璃模式（`.thickMaterial` 系统材质）和透明模式（`.ultraThinMaterial`），各自独立强度控制
- **锁定/编辑双模式**：锁定模式防误触（全窗口拖拽），编辑模式支持操作
- **按分类分组显示**：待办按分类归组，带颜色标识
- **倒计时标签**：截止日期显示为"今天 18:00"、"明天"、"已过期"，过期项标红
- **优先级指示器**：红/橙/绿小圆点表示高/中/低优先级
- **原生拖拽**：AppKit `performDrag` 实现，丝滑跟手，鼠标悬停手型反馈 + 高亮效果
- **窗口位置记忆**：重启后自动恢复上次位置和显示设置

### 主窗口
- **四标签页**：待办、分类、历史、设置
- **待办**：增强表单（分类选择、优先级、截止日期），分类筛选器，拖拽排序
- **分类管理**：新增/编辑/删除分类，自定义颜色和图标
- **历史**：已完成事项按日期分组（今天/昨天/具体日期），支持恢复和永久删除
- **设置**：悬浮窗模式切换、强度控制、通知提醒配置、开机自启动、版本信息

### 系统通知
- 截止日期前提醒通知（可配置：5分/15分/30分/1小时/1天）
- 过期待办启动时汇总提醒

### 菜单栏
- 顶部状态栏图标，点击弹出快捷面板
- 快速添加待办、切换悬浮窗、打开主窗口、退出
- 支持键盘快捷键（Cmd+C/V/X/A/Z）

### 技术特点
- 菜单栏应用（无 Dock 图标），主窗口打开时临时显示
- Liquid Glass / macOS 26 原生材质
- Swift 6 严格并发
- `UserDefaults` + `JSONEncoder` 数据持久化，向后兼容迁移
- 单实例 `TodoStore` 全局共享（待办 + 分类 + 历史）
- `UNUserNotificationCenter` 系统通知

## 技术栈

- **语言**：Swift 6
- **UI**：SwiftUI + AppKit（`NSHostingController` 桥接）
- **平台**：macOS 26+
- **架构**：AppKit 生命周期（`AppDelegate`）+ SwiftUI 内容渲染
- **数据层**：本地 SPM 包 `DeskTipsCore`（`TodoStore` + `SettingsStore`）
- **通知**：`UNUserNotificationCenter` + `NotificationManager`
- **构建**：Xcode + xcodebuild

## 项目结构

```
desk_tips/
├── DeskTips.xcodeproj/
├── DeskTips/
│   ├── App/
│   │   ├── main.swift                   # 入口 + 隐藏 Edit 菜单
│   │   ├── AppDelegate.swift            # 生命周期协调
│   │   ├── StatusBarController.swift    # 菜单栏图标 + 弹窗
│   │   ├── OverlayWindowController.swift # 悬浮窗管理
│   │   └── MainWindowController.swift   # 主窗口管理
│   ├── Views/
│   │   ├── OverlayContentView.swift     # 悬浮窗（分类分组+倒计时）
│   │   ├── SettingsView.swift           # 菜单栏弹窗
│   │   ├── MainTabView.swift            # 4标签页容器
│   │   ├── TodoListView.swift           # 待办列表+增强表单
│   │   ├── CategoryManageView.swift     # 分类管理
│   │   ├── HistoryView.swift            # 历史按日期
│   │   └── MainSettingsView.swift       # 设置+通知配置
│   ├── Services/
│   │   └── NotificationManager.swift    # 系统通知管理
│   └── Resources/
├── DeskTipsCore/                        # SPM 数据层
│   ├── Sources/DeskTipsCore/
│   │   ├── Models/
│   │   │   ├── Category.swift           # 分类模型 + Priority 枚举
│   │   │   ├── TodoItem.swift           # 待办模型（分类+截止+优先级）
│   │   │   ├── TodoStore.swift          # 待办+分类+历史存储
│   │   │   ├── OverlaySettings.swift    # 悬浮窗设置
│   │   │   └── SettingsStore.swift      # 设置存储
│   │   └── Protocols/
│   │       ├── PersistenceService.swift
│   │       └── SettingsPersistence.swift
│   └── Tests/                           # 30 个单元测试
└── README.md
```

## 构建与运行

```bash
git clone https://github.com/hhcme/desk_tips.git
cd desk_tips

# 测试核心包
cd DeskTipsCore && swift test

# 构建 App
cd ..
xcodebuild -project DeskTips.xcodeproj -scheme DeskTips -configuration Debug build

# 运行
open ~/Library/Developer/Xcode/DerivedData/DeskTips-*/Build/Products/Debug/DeskTips.app
```

## 系统要求

- macOS 26 (Tahoe) 或更高版本
- Xcode 26+
- Swift 6.3+

## License

MIT
