# LAN Clipboard Sync（Mac + Android）

> 你是小白也没关系：下面我按“照着点、照着复制命令”的方式写了最简步骤。

这是一个**局域网剪贴板同步**软件（MVP）：
- Mac 当主机（Host）
- Android 当客户端（Client）
- 支持文本剪贴板同步（手动 + 自动）

---

## 先说结论（你最关心的）

你最终会拿到：
- Android 安装包：`app-release.apk`
- Mac 可运行程序：`lan_clipboard_sync.app`

> 注意：本仓库是源码项目，需要在你自己的 Mac 上执行打包命令来生成安装包。

---

## 0）源码下载（给 openclaw 用）

你可以把本仓库源码直接给 openclaw，推荐 2 种方式：

### 方式 A：Git 下载（推荐）

```bash
git clone <你的仓库地址> lan-clipboard-sync
cd lan-clipboard-sync
```

然后把整个 `lan-clipboard-sync` 文件夹发给 openclaw，或让 openclaw 直接 `git clone`。

### 方式 B：ZIP 下载（不会 Git 也能用）

1. 打开仓库网页
2. 点击 **Code**
3. 点击 **Download ZIP**
4. 解压后把整个文件夹给 openclaw

> openclaw 拿到源码后，先按本文档的“准备工作 / 运行 / 打包”步骤执行即可。

---

## 一、准备工作（只做一次）

1. 准备一台 Mac（建议较新系统）。
2. 安装 Flutter（官方教程）：https://docs.flutter.dev/get-started/install/macos
3. 安装 Android Studio（用于安卓构建和设备支持）。
4. 打开终端，进入项目目录后执行：

```bash
./scripts/00_check_env.sh
```

如果这一步没有报错，就说明环境基本 OK。

---

## 二、第一次拉起项目（只做一次）

在项目目录执行：

```bash
./scripts/01_get_deps.sh
```

---

## 三、先跑起来看效果（最简单验证）

### 1) Mac 端（Host）运行

```bash
./scripts/10_run_macos_host.sh
```

应用打开后：
- 进入 **Host** 标签页
- 端口保持默认 `8787`
- 点 **启动 Host**
- 记下页面显示的“本机 IP”（如 `192.168.1.10`）

### 2) Android 端（Client）运行

把安卓手机连接到同一 Wi-Fi（和 Mac 同一个局域网），再执行：

```bash
./scripts/11_run_android_client.sh
```

应用打开后：
- 进入 **Client** 标签页
- Host IP 填刚才 Mac 显示的 IP
- 端口填 `8787`
- 点 **连接 Host**

### 3) 测试同步

- 在 Mac 复制一段文字，点 **立即同步当前剪贴板**
- 到 Android 粘贴，应该能看到新内容
- 反向同理

---

## 四、打包成“可安装本体”

### A. 打包 Android APK

执行：

```bash
./scripts/20_build_android_apk.sh
```

生成文件：
- `build/app/outputs/flutter-apk/app-release.apk`

把这个 APK 发到手机安装即可（首次可能需要“允许安装未知来源应用”）。

### B. 打包 Mac App

执行：

```bash
./scripts/21_build_macos_app.sh
```

生成文件：
- `build/macos/Build/Products/Release/lan_clipboard_sync.app`

双击即可运行（首次可能要在“系统设置-隐私与安全性”里允许）。

---

## 五、使用时的固定步骤（给非技术同学）

每次使用只要：
1. Mac 和 Android 连接同一 Wi-Fi。
2. Mac 打开 app，Host 页面点“启动 Host”。
3. Android 打开 app，Client 页面输入 Mac IP + 8787，点“连接 Host”。
4. 需要时点“立即同步当前剪贴板”或开启“自动同步”。

---

## 六、常见问题（非常实用）

### 1) Android 连接不上 Host

按顺序检查：
- 两端是否同一局域网。
- Host IP 是否填错（不要填 `127.0.0.1`）。
- Mac 防火墙是否拦截了 `8787` 端口。

### 2) 能连接但没同步

- 目前 MVP 主要同步**文本**，图片/文件暂不支持。
- 先试“立即同步当前剪贴板”按钮，确认基础链路正常。

### 3) 命令报 `flutter: command not found`

说明 Flutter 没装好，回到“准备工作”重新安装并执行：

```bash
./scripts/00_check_env.sh
```

---

## 七、项目当前能力边界（避免预期过高）

当前版本是 MVP，已可用但还不是商用完整版：
- ✅ 文本剪贴板同步
- ✅ Mac Host + Android Client
- ❌ mDNS 自动发现（暂未做）
- ❌ 配对码/端到端加密（暂未做）
- ❌ 图片/文件剪贴板同步（暂未做）

---

## 八、给你的一句话建议

如果你希望我下一步继续做成“真正可发布给普通用户安装”的版本，我建议按这个顺序升级：
1. 自动发现设备（免输 IP）
2. 配对码 + 加密
3. Android 后台常驻能力
4. 正式签名与安装包分发流程
