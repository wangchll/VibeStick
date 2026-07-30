# VibeStick 小红书发布文案

## 推荐标题

我把 StickS3 做成了 AI 编程语音终端｜开源 VibeStick

## 备选标题

- 不想一直敲键盘？我给 AI 编程做了个语音遥控器
- 这个小屏幕，现在能看 Codex 状态、语音输入、还能按键操作
- StickS3 + Mac：一个放在桌面上的 AI 编程伙伴

## 正文

最近把 M5Stack StickS3 改造成了一个桌面 AI 编程终端，项目叫 **VibeStick** 🎙️

它会在小屏幕上显示 Codex 的任务状态、运行中对话数和用量，也可以直接长按实体按键语音输入到 Mac。

目前做了 3 种语音模式：

☁️ **云端 API**：速度快，适合日常输入

💻 **本地 Whisper**：录音不离开电脑

💬 **微信语音输入**：识别结果直接写进当前输入框

按键也不只是开始录音：

- 蓝键长按：语音输入
- 蓝键单击：发送当前草稿
- 蓝键双击：暂停 Codex 任务
- 右侧键：允许、拒绝授权，还可以清空语音草稿

微信输入模式的原理挺有意思：StickS3 把音频传到 Mac，Bridge 把它写入 `BlackHole 2ch` 虚拟声卡，同时模拟长按 Fn，最后由微信输入法把文字写进当前输入框。

⚠️ 这里有个容易忽略的点：**BlackHole 2ch 需要自己安装，VibeStick 安装器目前不会自动安装它。**

整个项目已经开源，适合有 StickS3、喜欢硬件 DIY，或者想把 AI 编程工作流做得更“有实体感”的人。

🙏 特别感谢 VibeStick 原项目作者 **GaryGaryyy** 开源这个很有创意的项目，为 StickS3 与 AI 编程工作流的结合打下了基础。也感谢直接上游 fork 版本作者 **deanxizian** 对项目的继续开发与分享。当前由 **wangchll** 继续维护这个 fork 版本。

原项目：GitHub 搜索 **GaryGaryyy/VibeStick**

直接上游 fork：GitHub 搜索 **deanxizian/VibeStick**

当前 fork 版本：GitHub 搜索 **wangchll/VibeStick**

你们更想看哪部分：固件、Mac Bridge，还是微信语音输入的完整配置？

## 标签

#AI编程 #Codex #开源项目 #M5Stack #StickS3 #嵌入式开发 #语音输入 #Mac软件 #程序员的日常 #硬件DIY

## 置顶评论

补充一下微信语音模式：需要先安装微信输入法和 `BlackHole 2ch`，保留默认的长按 Fn 说话，再给 VibeStick 微信语音输入 helper 开启 macOS 辅助功能权限。BlackHole 目前不会随安装器自动安装。
