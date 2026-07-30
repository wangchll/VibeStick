import Foundation
import VibeStickSetupCore

public final class LocalSystemProbe: SystemProbing, @unchecked Sendable {
    private let projectRoot: URL
    private let serialDiscovery: IOKitSerialDiscovery
    private let addressResolver: LANAddressResolver
    private let fileManager: FileManager

    public init(
        projectRoot: URL,
        serialDiscovery: IOKitSerialDiscovery = .init(),
        addressResolver: LANAddressResolver = .init(),
        fileManager: FileManager = .default
    ) {
        self.projectRoot = projectRoot
        self.serialDiscovery = serialDiscovery
        self.addressResolver = addressResolver
        self.fileManager = fileManager
    }

    public func snapshot() async -> SystemSnapshot {
        let task = Task.detached(priority: .utility) { [self] in
            let addresses = addressResolver.resolve()
            let devices = serialDiscovery.discover()
            let python = findPython()
            let bridgePlist = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/com.vibestick.bridge.plist")
            let bridgeAvailable = fileManager.fileExists(atPath: bridgePlist.path)

            return SystemSnapshot(
                networkAddresses: addresses,
                serialDevices: devices,
                prerequisites: [
                    python,
                    Prerequisite(
                        kind: .bridge,
                        available: bridgeAvailable,
                        detail: bridgeAvailable ? "LaunchAgent 已安装" : "尚未安装 Mac Bridge",
                        path: bridgeAvailable ? bridgePlist.path : nil
                    ),
                ]
            )
        }
        return await task.value
    }

    private func findPython() -> Prerequisite {
        var candidates: [String] = []
        if let configured = configuredPython(), !configured.isEmpty { candidates.append(configured) }
        candidates.append(managedPythonPath())
        candidates += [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3",
        ]
        for candidate in unique(candidates) where fileManager.isExecutableFile(atPath: candidate) {
            let check = run(candidate, ["-c", "import sys; print('.'.join(map(str, sys.version_info[:3]))); raise SystemExit(0 if sys.version_info >= (3, 11) else 1)"])
            if check.status == 0 {
                return Prerequisite(kind: .python, available: true, detail: "Python \(check.output.trimmingCharacters(in: .whitespacesAndNewlines))", path: candidate)
            }
        }
        return Prerequisite(kind: .python, available: false, detail: "需要 Python 3.11 或更新版本")
    }

    private func managedPythonPath() -> String {
        #if arch(arm64)
        let architecture = "aarch64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unsupported"
        #endif
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/vibestick/python/cpython-3.12-macos-\(architecture)-none/bin/python3.12")
            .path
    }

    private func configuredPython() -> String? {
        let envURL = projectRoot.appendingPathComponent(".env")
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            guard line.hasPrefix("VIBE_STICK_PYTHON=") else { continue }
            var value = String(line.dropFirst("VIBE_STICK_PYTHON=".count)).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.first == value.last, value.first == "'" || value.first == "\"" {
                value.removeFirst()
                value.removeLast()
            }
            return value
        }
        return nil
    }

    private func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(decoding: data.prefix(16_384), as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
