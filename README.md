# VimScroll

VimScroll 是一个轻量的原生 macOS 菜单栏应用。按住 **Caps Lock（大写锁定键）**，再按 `H` / `J` / `K` / `L`，即可按照 Vim 的方向键顺序连续滚动鼠标指针所在的区域。

## 功能

| 快捷键 | 滚动方向 |
| --- | --- |
| Caps Lock + H | 左 |
| Caps Lock + J | 下 |
| Caps Lock + K | 上 |
| Caps Lock + L | 右 |

- 全局生效，不需要先点击目标窗口或滚动区域。
- 滚动事件始终发送到鼠标指针当前所在位置；按住快捷键移动鼠标时，目标区域会立即跟随。
- 按住按键即可连续平滑滚动，支持慢、标准、快三档速度。
- 可以同时按两个方向键进行斜向滚动。
- 按住 Caps Lock 时，鼠标旁显示蓝色 `⇪` 方向环；松开后立即消失。
- 仅显示菜单栏图标，不占用 Dock。菜单中可以暂停、调整速度或退出应用。
- 同时支持 Intel 和 Apple Silicon Mac。

## Caps Lock 行为

VimScroll 启用时，Caps Lock 会被转换为按住生效的滚动修饰键，原本的大小写锁定事件会被拦截。暂停或退出 VimScroll 后，Caps Lock 会恢复系统默认行为。

与读取 Caps Lock 的锁定灯状态不同，VimScroll 读取按键的物理按下/松开状态，因此其行为与 Shift、Command 等普通修饰键一致。

## 使用方法

1. 将 `VimScroll.app` 放入“应用程序”目录并打开。
2. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 VimScroll。
3. 确认菜单栏四向箭头图标中的状态为“监听中”。
4. 按住 Caps Lock。鼠标旁出现蓝色方向环后，使用 `H` / `J` / `K` / `L` 滚动。

如果授权后没有立即生效，请退出并重新打开 VimScroll。若 macOS 仍保留旧版本的权限记录，可在辅助功能列表中删除 VimScroll，再重新添加 `/Applications/VimScroll.app`。

## 功能设计

VimScroll 使用 AppKit、ApplicationServices 和 CoreGraphics 实现，不依赖第三方运行时。

```text
Caps Lock / H J K L
        │
        ▼
CGEventTap 全局键盘监听 ──────► Caps Lock 状态方向环
        │
        ▼
方向键集合 + 60 Hz 连续滚动定时器
        │
        ▼
读取每一帧的当前鼠标坐标
        │
        ▼
发布像素级 CGEvent 滚轮事件
        │
        ▼
鼠标所在窗口或内嵌滚动区域
```

### 全局键盘监听

应用在 session 级别创建主动 `CGEventTap`，监听 `flagsChanged`、`keyDown` 和 `keyUp`。当 VimScroll 启用时，它会拦截 Caps Lock 以及组合中的 `H/J/K/L`，避免触发大小写切换或向当前输入框写入字符。

Caps Lock 是锁存式修饰键，事件中的 `.maskAlphaShift` 只表示大小写锁定状态，无法可靠区分物理按下与松开。VimScroll 因此通过 `CGEventSource.keyState(.hidSystemState)` 获取真实按键状态，同时兼容键盘将 Caps Lock 报告为普通 `keyDown` / `keyUp` 的情况。

### 连续滚动

首次按下方向键时立即发送一帧滚动，并启动约 60 Hz 的 `DispatchSourceTimer`。定时器把当前按住的方向合成为二维向量，再根据所选速度生成像素级滚轮事件。所有方向键松开或 Caps Lock 松开后，定时器立即停止。

默认三档速度分别为每帧 5、10、18 像素，选择结果保存在 `UserDefaults` 中。

### 鼠标区域命中

macOS 根据滚轮事件的位置决定接收滚动的窗口与内嵌区域。VimScroll 在每一帧发布事件前重新读取当前指针位置，并写入 `CGEvent.location`。因此即使键盘焦点位于另一个窗口，滚动仍会命中鼠标所在的网页面板、列表或分栏区域。

### 状态提示

Caps Lock 按下时，应用创建一个透明、不可激活、忽略鼠标事件的 `NSPanel`，在指针周围绘制蓝色方向环。面板加入所有桌面空间并跟随鼠标移动，不会抢占焦点或阻挡鼠标命中。

### 权限与隐私

全局键盘事件监听和合成滚轮事件需要 macOS“辅助功能”权限。VimScroll 只在本机处理 Caps Lock 与 `H/J/K/L` 的状态，不记录文本、不保存按键历史，也不发送网络请求。

## 项目结构

```text
VimScroll/
├── Package.swift                         # Swift Package 定义
├── project.yml                           # 可选的 XcodeGen 工程定义
├── build_app.sh                          # 通用架构 .app 打包脚本
├── VimScroll/
│   ├── AppDelegate.swift                 # 菜单栏、授权和生命周期
│   ├── CursorIndicatorController.swift   # 鼠标方向环
│   ├── ScrollController.swift            # 键盘监听与滚动核心
│   ├── ScrollDirection.swift             # Vim 按键映射和速度
│   ├── Info.plist
│   └── main.swift
└── VimScrollTests/
    └── ScrollDirectionTests.swift
```

## 从源码构建

要求 macOS 13 或更高版本，以及 Swift 工具链。安装 Xcode Command Line Tools 即可：

```bash
xcode-select --install
chmod +x build_app.sh
./build_app.sh
```

构建产物位于 `dist/`：

- `VimScroll.app`
- `VimScroll-macOS.zip`

脚本分别编译 `x86_64` 和 `arm64`，通过 `lipo` 合成通用二进制，并进行本地 ad-hoc 签名。

也可以直接打开生成的 Xcode 工程进行开发：

```bash
brew install xcodegen
xcodegen generate
open VimScroll.xcodeproj
```

## 测试

```bash
swift test
```

测试覆盖 Vim 风格按键映射和滚动方向向量。涉及辅助功能权限、全局事件和窗口命中的部分需要在真实 macOS 会话中进行集成测试。

## 常见问题

### 菜单栏显示“需要辅助功能权限”

打开“系统设置 → 隐私与安全性 → 辅助功能”，允许 `/Applications/VimScroll.app`。如果列表中已有旧版本，请删除后重新添加新版本。

### 按住 Caps Lock 只出现系统的 `A` 标记

这表示 macOS 仍在执行原始 Caps Lock 行为，VimScroll 尚未获得权限或监听尚未启动。检查菜单状态和辅助功能授权，然后重新启动应用。

### 密码输入界面中不生效

部分密码框、锁屏或启用 Secure Input 的应用会限制全局键盘监听，这是 macOS 的安全机制。

## License

Apache License 2.0。详见 [LICENSE](LICENSE)。
