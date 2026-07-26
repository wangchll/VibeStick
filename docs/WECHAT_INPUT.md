# 微信输入法语音输入（MVP）

此模式把 StickS3 完成录制后上传的 WAV 播放到 macOS 虚拟音频设备，并在
播放前后触发微信输入法的切换式语音快捷键。微信输入法直接把识别结果写入
当前输入框，Bridge 不会获得或保存转写文本。

## 前置设置

1. 安装一个同时提供输入和输出端的回环设备，例如 `BlackHole 2ch`。
2. 在微信输入法的语音设置中，把麦克风固定为同一个设备。
3. 把微信输入法语音快捷键设置为“按一下开始、再按一下停止”，默认使用
   `Control + Option + Space`。
4. 在 `.env` 中设置：

   ```dotenv
   VIBE_STICK_EXTERNAL_INPUT_PROVIDER=wechat-input
   VIBE_STICK_EXTERNAL_INPUT_DEVICE=BlackHole 2ch
   VIBE_STICK_EXTERNAL_INPUT_KEYCODE=49
   VIBE_STICK_EXTERNAL_INPUT_MODIFIERS=control,option
   ```

5. 重新运行安装器。首次使用时，在“系统设置 → 隐私与安全性 → 辅助功能”
   中允许 `VibeStick 微信语音输入` 控制键盘。

macOS 虚拟键码 `49` 是空格键。修饰键支持 `control`、`option`、`shift`、
`command` 和 `fn`，使用英文逗号分隔。

## 当前限制

- MVP 在松开 StickS3 按键、完整 WAV 上传后才开始回放，因此总等待时间约为
  “说话时长 + 微信识别耗时”。后续流式版本会在按住期间实时传输 PCM。
- 微信输入法必须正在使用切换式快捷键，且焦点应停留在可编辑输入框。
- 音频会按照微信输入法自身的隐私和联网策略处理，而不是本机离线 ASR。
- `BlackHole` 不随 VibeStick 分发，其安装与许可证由对应项目负责。
