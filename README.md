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
- **五标签页**：待办、分类、历史、设置、关于
- **待办**：增强表单（分类选择、优先级、截止日期），分类筛选器，拖拽排序
- **分类管理**：新增/编辑/删除分类，自定义颜色和图标
- **历史**：已完成事项按日期分组（今天/昨天/具体日期），支持恢复和永久删除
- **设置**：悬浮窗模式切换、强度控制、通知提醒配置、开机自启动
- **关于**：版本信息、GitHub 仓库入口、应用内更新检查与更新说明

### 系统通知
- 截止日期前提醒通知（可配置：5分/15分/30分/1小时/1天）
- 过期待办启动时汇总提醒

### 应用内更新
- Sparkle 2 自更新：启动后静默检查更新，关于页可手动检查并展示更新日志
- 更新提醒：发现新版本时菜单栏图标和关于页显示红点
- GitHub Releases 分发：DMG 和 `appcast.xml` 作为同一个 release 的资产发布
- 更新包使用 EdDSA 签名校验，防止安装包被篡改

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
│   │   ├── MainSettingsView.swift       # 设置+通知配置
│   │   └── MainAboutView.swift          # 版本、仓库与更新检查
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

## 发布更新

DeskTips 使用 Sparkle + GitHub Releases 做应用内更新。客户端读取：

```text
https://github.com/hhcme/desk_tips/releases/latest/download/appcast.xml
```

本地生成发布物：

```bash
VERSION=1.1.1 BUILD=111 ./scripts/package_release.sh
```

产物会写入：

```text
dist/DeskTips-1.1.1-macOS.dmg
dist/appcast.xml
```

Sparkle 自更新要求发布包同时满足两层签名：

- Apple Code Signing：App、Sparkle framework 和 helper 必须使用稳定的 Developer ID Application 身份签名。
- Sparkle EdDSA：`appcast.xml` 里的 enclosure 必须由 Sparkle 私钥签名。

如果发布包是 ad-hoc 签名，客户端可以下载更新，但安装阶段会失败。

首次配置 GitHub Actions 前，需要把 Sparkle 私钥导出到仓库 secret：

```bash
~/Library/Developer/Xcode/DerivedData/DeskTips-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.desktips.app \
  -x /tmp/desktips_sparkle_private_key

pbcopy < /tmp/desktips_sparkle_private_key
```

然后在 GitHub 仓库添加这些 secrets：

```text
SPARKLE_PRIVATE_KEY
APPLE_DEVELOPER_ID_CERTIFICATE_BASE64
APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD
KEYCHAIN_PASSWORD
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
```

`APPLE_DEVELOPER_ID_CERTIFICATE_BASE64` 是 Developer ID Application 证书的 `.p12` 文件 base64 内容：

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

推送 tag 后会自动签名、公证、生成 appcast 并发布：

```bash
git tag v1.1.1
git push origin v1.1.1
```

Sparkle 会读取 `appcast.xml` 里的 Markdown 更新日志，客户端会解析后在主窗口“关于”页内展示。

## 系统要求

- macOS 26 (Tahoe) 或更高版本
- Xcode 26+
- Swift 6.3+

## License

MIT
