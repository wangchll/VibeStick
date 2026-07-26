# 微信输入法语音输入（MVP）

此模式把 StickS3 完成录制后上传的 WAV 播放到 macOS 虚拟音频设备，并在
播放期间模拟长按微信输入法默认的 Fn 语音快捷键。微信输入法直接把识别结果写入
当前输入框，Bridge 不会获得或保存转写文本。

## 前置设置

1. 安装一个同时提供输入和输出端的回环设备，例如 `BlackHole 2ch`。
2. 保持微信输入法默认的“长按 Fn 说话”快捷键，无需修改微信输入法设置。
3. 在 `.env` 中设置：

   ```dotenv
   VIBE_STICK_EXTERNAL_INPUT_PROVIDER=wechat-input
   VIBE_STICK_EXTERNAL_INPUT_DEVICE=BlackHole 2ch
   VIBE_STICK_EXTERNAL_INPUT_SHORTCUT_MODE=fn-hold
   VIBE_STICK_EXTERNAL_INPUT_KEYCODE=63
   VIBE_STICK_EXTERNAL_INPUT_MODIFIERS=fn
   ```

4. 重新运行安装器。首次使用时，在“系统设置 → 隐私与安全性 → 辅助功能”
   中允许 `VibeStick 微信语音输入` 控制键盘。

macOS 虚拟键码 `63` 是 Fn 键。helper 会在回放开始前按下 Fn，持续到整段
录音播放完成后再松开。备用的 `toggle` 模式仍支持 `control`、`option`、
`shift`、`command` 和 `fn` 修饰键。

helper 只在一次语音会话期间把系统默认输入临时切到 BlackHole；Fn 松开后
立即恢复原来的默认麦克风。系统默认输出设备不会被修改。

微信输入法会把识别结果写入触发语音会话时拥有键盘焦点的应用。测试时请先
把光标放入目标文本框，并避免在识别完成前切换到终端或其他应用。
helper 会先确认当前输入源是微信输入法；如果当前是 ABC、系统拼音或其他
输入法，会终止本次会话并返回明确错误，避免把单纯播放音频误报为输入成功。

## 当前限制

- MVP 在松开 StickS3 按键、完整 WAV 上传后才开始回放，因此总等待时间约为
  “说话时长 + 微信识别耗时”。后续流式版本会在按住期间实时传输 PCM。
- 微信输入法需要启用默认的长按 Fn 语音输入，且焦点应停留在可编辑输入框。
- 音频会按照微信输入法自身的隐私和联网策略处理，而不是本机离线 ASR。
- `BlackHole` 不随 VibeStick 分发，其安装与许可证由对应项目负责。
