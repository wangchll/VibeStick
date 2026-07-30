# VibeStick v0.3.11 安装说明

## 下载包

下载 `VibeStickSetup-0.3.11-macOS-arm64.zip`，适用于 Apple Silicon Mac（M1 或更新机型）和 macOS 14 或更高版本。

安装器已经包含：

- StickS3 v0.3.11 通用固件、分区表和 bootloader；
- Apple Silicon 与 Intel 两种架构的 ESP32-S3 刷写工具；
- Apple Silicon 与 Intel 两种架构的 Python 3.12 Runtime；
- 预编译的 VibeStick Bridge、HUD 和菜单栏组件；
- 固件清单、SHA-256 校验信息和设备配置生成工具。

普通安装机器不需要安装 Xcode、Git、Python 或 ESP-IDF。

## 安装前准备

- Apple Silicon Mac，macOS 14 或更高版本；
- M5Stack StickS3；
- 可传输数据的 USB-C 线；
- 2.4 GHz Wi-Fi 名称和密码；
- 可选的云端语音转写 API Key。

## 完整安装步骤

1. 下载 ZIP 和同名 `.sha256` 文件。可选地在终端进入下载目录并运行：

   ```sh
   shasum -a 256 -c VibeStickSetup-0.3.11-macOS-arm64.zip.sha256
   ```

2. 解压 ZIP，将 `VibeStickSetup.app` 拖到“应用程序”文件夹。
3. 第一次启动时，按住 Control 点击安装器并选择“打开”。如果 macOS 仍阻止启动，请打开“系统设置 → 隐私与安全性”，确认该 App 来自本项目下载包后选择“仍要打开”。
4. 在安装器中填写 Wi-Fi、提醒音音量和可选的语音服务配置。
5. 使用 USB-C 数据线连接 StickS3，按照界面提示进入下载模式。
6. 确认安装。安装器会验证内置文件、生成设备专属配置、烧录 StickS3、安装 Mac 服务并等待设备联网。
7. 首次使用语音或物理按键控制时，按系统提示为 VibeStick 开启“麦克风”和“辅助功能”权限。

安装或刷写期间请勿拔掉数据线。Mac 与 StickS3 必须连接同一个可信局域网。

## 更新与重新配置

使用新版安装器重复安装即可更新 Mac 组件和固件。安装器会保留现有 `.env` 与设备 secrets；修改 Wi-Fi、音量或语音服务配置时也使用同一安装器。

不要直接复制 Bridge 文件或使用裸 `idf.py flash` 作为正式更新方式。

## 签名说明

v0.3.11 下载包是项目当前机器生成的 ad-hoc 签名构建，尚未使用 Apple Developer ID 公证，因此首次打开需要手动确认。它不是经过 Apple 公证的 DMG；不要从本项目 GitHub Release 之外的来源下载。

## 常见问题

- **提示“验证通用固件失败”**：重新下载完整 ZIP，先核对 SHA-256，再重新解压；不要修改 `.app` 包内文件。
- **检测不到 StickS3**：确认使用数据线，重新连接并严格按照安装器提示进入下载模式。
- **设备无法联网**：StickS3 仅支持 2.4 GHz Wi-Fi，并需要与 Mac 位于同一局域网。
- **按键无法控制 ChatGPT**：确认已安装同一版本的 Mac 组件，并在系统设置中允许辅助功能权限。
- **语音能转写但不能粘贴**：确认麦克风和辅助功能权限均已授予。

项目主页与问题反馈：<https://github.com/wangchll/VibeStick>
