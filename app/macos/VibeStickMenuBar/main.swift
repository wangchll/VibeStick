import AppKit
import Foundation

// MARK: - Paths
let home = NSHomeDirectory()
let vsDir = (home as NSString).appendingPathComponent("Library/Application Support/VibeStick")
let launchAgentsDir = (home as NSString).appendingPathComponent("Library/LaunchAgents")
let uidString = String(getuid())

let bridgeLabel = "com.vibestick.bridge"
let hudLabel = "com.vibestick.hud"

func plistPath(for label: String) -> String {
    (launchAgentsDir as NSString).appendingPathComponent("\(label).plist")
}

// MARK: - Shell helper
@discardableResult
func run(_ launchPath: String, _ args: [String]) -> (exit: Int32, output: String) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: launchPath)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    do {
        try proc.run()
    } catch {
        return (-1, "launch error: \(error)")
    }
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: data, encoding: .utf8) ?? ""
    return (proc.terminationStatus, out)
}

func serviceRunning(_ label: String) -> Bool {
    let (_, out) = run("/bin/launchctl", ["print", "gui/\(uidString)/\(label)"])
    for line in out.split(separator: "\n") {
        let l = line.trimmingCharacters(in: .whitespaces)
        if l.hasPrefix("pid =") {
            let v = l.replacingOccurrences(of: "pid =", with: "").trimmingCharacters(in: .whitespaces)
            if let n = Int(v), n > 0 { return true }
        }
    }
    return false
}

func toggleService(_ label: String) {
    let plist = plistPath(for: label)
    if serviceRunning(label) {
        run("/bin/launchctl", ["unload", plist])
    } else {
        run("/bin/launchctl", ["load", plist])
    }
}

func readState() -> [String: Any]? {
    let url = URL(fileURLWithPath: (vsDir as NSString).appendingPathComponent("state.json"))
    guard let data = try? Data(contentsOf: url) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

let idlePresets: [(label: String, seconds: Int)] = [
    ("永不", 0),
    ("15 秒", 15),
    ("30 秒", 30),
    ("1 分钟（默认）", 60),
    ("2 分钟", 120),
    ("5 分钟", 300),
]

enum VoiceInputMode: Equatable {
    case remote
    case localWhisper
    case wechatInput
}

/// POST JSON 到本机 bridge（默认端口 8765）。用于下发可配置项，如息屏时间。
func postJSON(_ path: String, _ payload: [String: Any], completion: ((Bool) -> Void)? = nil) {
    guard let url = URL(string: "http://127.0.0.1:8765\(path)") else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
    URLSession.shared.dataTask(with: req) { _, response, error in
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        completion?(error == nil && (200..<300).contains(status))
    }.resume()
}

func currentScreenIdleSeconds() -> Int {
    return (readState()?["screen_idle_off_ms"] as? Int) ?? 60
}

func gesturesEnabled() -> Bool {
    return (readState()?["gestures_enabled"] as? Bool) ?? false
}

func openFile(_ path: String) {
    run("/usr/bin/open", ["-e", path])
}

func openInstaller() {
    let candidates = [
        "/Applications/VibeStickSetup.app",
        (home as NSString).appendingPathComponent("Documents/Code/VibeStick/dist/VibeStickSetup.app"),
    ]
    for c in candidates {
        if FileManager.default.fileExists(atPath: c) {
            run("/usr/bin/open", [c])
            return
        }
    }
    let alert = NSAlert()
    alert.messageText = "找不到 VibeStickSetup.app"
    alert.informativeText = "请确认安装器位于 /Applications 或 ~/Documents/Code/VibeStick/dist/"
    alert.runModal()
}

final class GestureSettingsController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let enabled = NSButton(checkboxWithTitle: "启用空间手势", target: nil, action: nil)
    private let sensitivity = NSPopUpButton()
    private let windowLength = NSPopUpButton()
    private var fields: [String: NSTextField] = [:]
    private let gestureRows: [(String, String, String)] = [
        ("double_tap", "敲击两次 S3", "切换规划模式（本机：⌃⇧1）"),
        ("triple_tap", "敲击三次 S3", "切换快速模式（本机：⌃⇧@）"),
        ("shake", "连续摇晃 S3", "新建 Codex 任务（⌘N）"),
    ]

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 525),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        super.init()
        window.title = "VibeStick 空间手势"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.center()
        window.delegate = self
        buildUI()
    }

    func show() {
        loadState()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func buildUI() {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = NSView()
        window.contentView?.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            content.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor),
        ])

        enabled.font = .boldSystemFont(ofSize: 14)
        content.addArrangedSubview(enabled)
        let hint = NSTextField(wrappingLabelWithString: "同时按下蓝色前键和右侧大按键，启动一次短暂手势窗口；组合键不会触发两个按键原有操作。窗口内再敲击两次、敲击三次或连续摇晃 S3。")
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 3
        content.addArrangedSubview(hint)
        let motionHint = NSTextField(wrappingLabelWithString: "每个窗口最多执行一个动作。双击会短暂等待以区分三击；窗口启动和动作识别均有提示音，录音时不会启动。")
        motionHint.textColor = .secondaryLabelColor
        motionHint.font = .systemFont(ofSize: 11)
        motionHint.maximumNumberOfLines = 2
        content.addArrangedSubview(motionHint)

        sensitivity.addItems(withTitles: ["保守（推荐）", "标准", "灵敏"])
        windowLength.addItems(withTitles: ["3 秒", "4 秒（默认）", "5 秒", "6 秒"])
        let general = NSGridView(views: [
            [NSTextField(labelWithString: "识别灵敏度"), sensitivity],
            [NSTextField(labelWithString: "手势窗口"), windowLength],
        ])
        general.column(at: 0).xPlacement = .trailing
        general.rowSpacing = 8
        content.addArrangedSubview(general)

        let separator = NSBox()
        separator.boxType = .separator
        separator.widthAnchor.constraint(equalToConstant: 572).isActive = true
        content.addArrangedSubview(separator)
        let mappingTitle = NSTextField(labelWithString: "手势与快捷键映射")
        mappingTitle.font = .boldSystemFont(ofSize: 13)
        content.addArrangedSubview(mappingTitle)

        var rows: [[NSView]] = []
        for (key, title, defaultDescription) in gestureRows {
            let label = NSTextField(labelWithString: title)
            let field = NSTextField(string: "default")
            field.placeholderString = "default / disabled / command+shift+k"
            field.widthAnchor.constraint(equalToConstant: 220).isActive = true
            field.toolTip = "默认：\(defaultDescription)。输入 default、disabled，或 command+shift+k 格式。"
            fields[key] = field
            let detail = NSTextField(labelWithString: defaultDescription)
            detail.textColor = .secondaryLabelColor
            detail.font = .systemFont(ofSize: 11)
            rows.append([label, field, detail])
        }
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.columnSpacing = 10
        grid.rowSpacing = 8
        content.addArrangedSubview(grid)

        let syntax = NSTextField(wrappingLabelWithString: "本机 Codex 自定义键位已作为默认值：规划模式 control+shift+1，快速模式 control+shift+@。macOS 自定义格式示例：command+n、control+shift+1。")
        syntax.textColor = .secondaryLabelColor
        syntax.font = .systemFont(ofSize: 11)
        syntax.maximumNumberOfLines = 2
        content.addArrangedSubview(syntax)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let reset = NSButton(title: "恢复默认", target: self, action: #selector(resetDefaults))
        let save = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        save.keyEquivalent = "\r"
        buttons.addArrangedSubview(reset)
        buttons.addArrangedSubview(save)
        content.addArrangedSubview(buttons)
    }

    private func loadState() {
        let state = readState() ?? [:]
        enabled.state = ((state["gestures_enabled"] as? Bool) ?? false) ? .on : .off
        let sensitivityValue = (state["gesture_sensitivity"] as? String) ?? "conservative"
        sensitivity.selectItem(at: sensitivityValue == "sensitive" ? 2 : (sensitivityValue == "standard" ? 1 : 0))
        let milliseconds = (state["gesture_window_ms"] as? Int) ?? 4000
        let seconds = max(3, min(6, milliseconds / 1000))
        windowLength.selectItem(at: seconds - 3)
        let mappings = state["gesture_mappings"] as? [String: String] ?? [:]
        for (key, field) in fields {
            let mapping = mappings[key] ?? "default"
            field.stringValue = mapping.hasPrefix("shortcut:")
                ? String(mapping.dropFirst("shortcut:".count)) : mapping
        }
    }

    @objc private func resetDefaults() {
        enabled.state = .on
        sensitivity.selectItem(at: 0)
        windowLength.selectItem(at: 1)
        fields.values.forEach { $0.stringValue = "default" }
    }

    @objc private func saveSettings() {
        let sensitivityValues = ["conservative", "standard", "sensitive"]
        var mappings: [String: String] = [:]
        for (key, field) in fields {
            let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            mappings[key] = (raw == "default" || raw == "disabled") ? raw : "shortcut:\(raw)"
        }
        let payload: [String: Any] = [
            "enabled": enabled.state == .on,
            "window_ms": (windowLength.indexOfSelectedItem + 3) * 1000,
            "sensitivity": sensitivityValues[max(0, sensitivity.indexOfSelectedItem)],
            "mappings": mappings,
        ]
        postJSON("/api/gestures", payload) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else { return }
                if ok {
                    self.window.orderOut(nil)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "无法保存手势设置"
                    alert.informativeText = "请检查快捷键格式，并确认 Bridge 服务正在运行。"
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - Menu bar app
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var wifiItem: NSMenuItem?
    var providerItem: NSMenuItem?
    var projectItem: NSMenuItem?
    var bridgeItem: NSMenuItem?
    var hudItem: NSMenuItem?
    var asrRemoteItem: NSMenuItem?
    var asrLocalItem: NSMenuItem?
    var asrWeChatItem: NSMenuItem?
    var idleItems: [NSMenuItem] = []
    var gesturesItem: NSMenuItem?
    var gestureSettingsController: GestureSettingsController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            if let img = NSImage(systemSymbolName: "waveform.circle.fill",
                                 accessibilityDescription: "VibeStick") {
                img.isTemplate = true
                btn.image = img
            } else {
                btn.title = "VS"
            }
        }
        rebuildMenu()
        // Periodically refresh status text without rebuilding the menu (avoids flicker/close).
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let title = NSMenuItem(title: "VibeStick", action: nil, keyEquivalent: "")
        title.attributedTitle = NSAttributedString(
            string: "VibeStick",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(title)
        menu.addItem(.separator())

        wifiItem = infoItem("Wi-Fi", "")
        providerItem = infoItem("Provider", "")
        projectItem = infoItem("项目", "")
        menu.addItem(wifiItem!)
        menu.addItem(providerItem!)
        menu.addItem(projectItem!)
        menu.addItem(.separator())

        bridgeItem = toggleItem("Bridge 服务", on: false, action: #selector(toggleBridge))
        hudItem = toggleItem("HUD 浮层", on: false, action: #selector(toggleHud))
        menu.addItem(bridgeItem!)
        menu.addItem(hudItem!)
        menu.addItem(.separator())

        // 三种模式互斥；微信输入法是独立外部输入方式，不覆盖 Whisper 配置。
        let asrSub = NSMenu(title: "语音识别")
        let remoteItem = NSMenuItem(
            title: "远端大模型（SiliconFlow 云端）",
            action: #selector(selectRemoteASR),
            keyEquivalent: ""
        )
        remoteItem.target = self
        let localItem = NSMenuItem(
            title: "本机离线识别（本地 Whisper）",
            action: #selector(selectLocalASR),
            keyEquivalent: ""
        )
        localItem.target = self
        let wechatItem = NSMenuItem(
            title: "微信语音输入法（长按 Fn）",
            action: #selector(selectWeChatInput),
            keyEquivalent: ""
        )
        wechatItem.target = self
        asrSub.addItem(remoteItem)
        asrSub.addItem(localItem)
        asrSub.addItem(wechatItem)
        let asrTop = NSMenuItem(title: "语音识别模式", action: nil, keyEquivalent: "")
        asrTop.submenu = asrSub
        menu.addItem(asrTop)
        asrRemoteItem = remoteItem
        asrLocalItem = localItem
        asrWeChatItem = wechatItem

        // 息屏时间：通过 Mac 客户端下发，固件轮询 bridge /state 后即时生效（无需重烧固件）。
        let idleSub = NSMenu(title: "息屏时间")
        for preset in idlePresets {
            let it = NSMenuItem(title: preset.label, action: #selector(selectScreenIdle(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = preset.seconds
            idleSub.addItem(it)
            idleItems.append(it)
        }
        let idleTop = NSMenuItem(title: "息屏时间", action: nil, keyEquivalent: "")
        idleTop.submenu = idleSub
        menu.addItem(idleTop)

        gesturesItem = toggleItem("空间手势（前键 + 侧键启动）", on: false, action: #selector(toggleGestures))
        menu.addItem(gesturesItem!)
        let gestureSettings = NSMenuItem(title: "空间手势设置…", action: #selector(openGestureSettings), keyEquivalent: "")
        gestureSettings.target = self
        menu.addItem(gestureSettings)

        let cfg = NSMenuItem(title: "编辑配置 (.env)", action: #selector(editConfig), keyEquivalent: "")
        cfg.target = self
        menu.addItem(cfg)

        let inst = NSMenuItem(title: "打开安装器", action: #selector(openSetup), keyEquivalent: "")
        inst.target = self
        menu.addItem(inst)
        menu.addItem(.separator())

        let about = NSMenuItem(title: "关于 VibeStick v0.3.0", action: nil, keyEquivalent: "")
        menu.addItem(about)

        let quit = NSMenuItem(title: "退出菜单栏图标", action: #selector(quitMenuBar), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshStatus()
    }

    func refreshStatus() {
        let bridgeOn = serviceRunning(bridgeLabel)
        let hudOn = serviceRunning(hudLabel)
        let state = readState()
        let wifi = (state?["wifi"] as? Bool) ?? false
        let providerName = (state?["active_provider"] as? String) ?? "—"
        let provider = state?["provider"] as? [String: Any]
        let pstatus = provider?["status"] as? String ?? "—"
        let project = (provider?["project"] as? String) ?? ""

        wifiItem?.title = "Wi-Fi: \(wifi ? "已连接" : "未连接")"
        providerItem?.title = "Provider: \(providerName) · \(pstatus)"
        projectItem?.title = "项目: \(project)"
        projectItem?.isHidden = project.isEmpty
        bridgeItem?.title = "Bridge 服务：\(bridgeOn ? "● 开" : "○ 关")"
        hudItem?.title = "HUD 浮层：\(hudOn ? "● 开" : "○ 关")"
        let voiceMode = currentVoiceInputMode()
        asrRemoteItem?.state = voiceMode == .remote ? .on : .off
        asrLocalItem?.state = voiceMode == .localWhisper ? .on : .off
        asrWeChatItem?.state = voiceMode == .wechatInput ? .on : .off
        let curIdle = currentScreenIdleSeconds()
        for it in idleItems {
            if let secs = it.representedObject as? Int {
                it.state = (secs == curIdle) ? .on : .off
            }
        }
        let gesturesOn = gesturesEnabled()
        gesturesItem?.title = "空间手势（前键 + 侧键启动）：\(gesturesOn ? "● 开" : "○ 关")"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatus()
    }

    func infoItem(_ k: String, _ v: String) -> NSMenuItem {
        let item = NSMenuItem(title: "\(k): \(v)", action: nil, keyEquivalent: "")
        item.indentationLevel = 1
        return item
    }

    func toggleItem(_ name: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: "\(name)：\(on ? "● 开" : "○ 关")", action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func toggleBridge() { toggleService(bridgeLabel); refreshStatus() }
    @objc func toggleHud() { toggleService(hudLabel); refreshStatus() }
    @objc func toggleGestures() {
        postJSON("/api/gestures", ["enabled": !gesturesEnabled()])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshStatus() }
    }
    @objc func openGestureSettings() {
        // Delay until AppKit closes the status-item menu; presenting a window
        // while that menu tracks clicks is the intermittent no-window path.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.gestureSettingsController == nil {
                self.gestureSettingsController = GestureSettingsController()
            }
            self.gestureSettingsController?.show()
        }
    }
    @objc func editConfig() { openFile((vsDir as NSString).appendingPathComponent(".env")) }
    @objc func openSetup() { openInstaller() }
    @objc func quitMenuBar() { NSApp.terminate(nil) }

    // MARK: - 语音识别模式切换
    @objc func selectRemoteASR() { setVoiceInputMode(.remote) }
    @objc func selectLocalASR() { setVoiceInputMode(.localWhisper) }
    @objc func selectWeChatInput() { setVoiceInputMode(.wechatInput) }
    @objc func selectScreenIdle(_ sender: NSMenuItem) {
        guard let secs = sender.representedObject as? Int else { return }
        postJSON("/api/screen_idle", ["seconds": secs])
        refreshStatus()
    }

    func currentVoiceInputMode() -> VoiceInputMode {
        if readEnvValue("VIBE_STICK_EXTERNAL_INPUT_PROVIDER") == "wechat-input" {
            return .wechatInput
        }
        return readEnvValue("VIBE_STICK_ASR_PROVIDER") == "whisper-local"
            ? .localWhisper
            : .remote
    }

    /// 微信模式只启用 external-input；原有远程/Whisper 配置仍保留。
    /// 选择远程或 Whisper 时显式关闭 external-input，确保三种模式互斥。
    func setVoiceInputMode(_ mode: VoiceInputMode) {
        switch mode {
        case .remote:
            writeEnvValue("VIBE_STICK_EXTERNAL_INPUT_PROVIDER", "")
            writeEnvValue("VIBE_STICK_ASR_PROVIDER", "openai-compatible")
            writeEnvValue("VIBE_STICK_TRANSCRIBE_CMD", "")
        case .localWhisper:
            writeEnvValue("VIBE_STICK_EXTERNAL_INPUT_PROVIDER", "")
            writeEnvValue("VIBE_STICK_ASR_PROVIDER", "whisper-local")
            writeEnvValue("VIBE_STICK_TRANSCRIBE_CMD", "")
        case .wechatInput:
            writeEnvValue("VIBE_STICK_EXTERNAL_INPUT_PROVIDER", "wechat-input")
        }
        restartBridge()
        refreshStatus()
    }

    func restartBridge() {
        run("/bin/launchctl", ["kickstart", "-k", "gui/\(uidString)/\(bridgeLabel)"])
    }

    func readEnvValue(_ key: String) -> String {
        let path = (vsDir as NSString).appendingPathComponent(".env")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let k = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
            if k == key {
                var v = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                if v.count >= 2, let first = v.first, (first == "'" || first == "\""), v.last == first {
                    v = String(v.dropFirst().dropLast())
                }
                return v
            }
        }
        return ""
    }

    func writeEnvValue(_ key: String, _ value: String) {
        let path = (vsDir as NSString).appendingPathComponent(".env")
        let quoted = "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n")
        var found = false
        for i in 0..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let k = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
            if k == key {
                lines[i] = "\(key)=\(quoted)"
                found = true
                break
            }
        }
        if !found {
            lines.append("\(key)=\(quoted)")
        }
        let out = lines.joined(separator: "\n")
        try? out.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
