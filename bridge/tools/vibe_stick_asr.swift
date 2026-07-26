// VibeStick local on-device speech recognition helper.
// (build embeds an Info.plist via -sectcreate so TCC accepts NSSpeechRecognitionUsageDescription)
//
// Invoked by the bridge TranscriptionAdapter when
// VIBE_STICK_ASR_PROVIDER=apple-on-device. The recording session JSON is
// supplied on stdin; the helper reads `audio_file`, runs Apple's on-device
// Speech framework recognizer, and prints the transcript to stdout.
//
// Exit 0 with the transcript on stdout on success; exit 1 with a human
// readable message on stderr on failure. No audio ever leaves the machine:
// the audio is read from a local file and recognition runs on-device.
import AVFoundation
import Foundation
import Speech

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// 1. Read the session JSON from stdin.
let stdinData = FileHandle.standardInput.readDataToEndOfFile()
guard let jsonText = String(data: stdinData, encoding: .utf8),
      let jsonData = jsonText.data(using: .utf8),
      let session = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
else {
    fail("Apple on-device ASR: could not parse session JSON from stdin")
}

guard let audioPath = (session["audio_file"] as? String)?.nilIfEmpty else {
    fail("Apple on-device ASR: session JSON has no audio_file")
}

let audioURL = URL(fileURLWithPath: audioPath)
guard FileManager.default.fileExists(atPath: audioPath) else {
    fail("Apple on-device ASR: audio file not found: \(audioPath)")
}

// 2. Resolve the recognition locale from configuration.
let rawLanguage = (ProcessInfo.processInfo.environment["VIBE_STICK_ASR_LANGUAGE"] ?? "zh")
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
let localeIdentifier: String
switch rawLanguage {
case "zh", "zh-cn", "zh_cn", "chinese":
    localeIdentifier = "zh-CN"
case "en", "en-us", "en_us", "english":
    localeIdentifier = "en-US"
default:
    localeIdentifier = rawLanguage.isEmpty ? "zh-CN" : rawLanguage
}

guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
    fail("Apple on-device ASR: speech recognition is unavailable for locale \(localeIdentifier)")
}

// 3. Ensure Speech Recognition permission is granted.
let currentStatus = SFSpeechRecognizer.authorizationStatus()
if currentStatus == .notDetermined {
    let group = DispatchGroup()
    group.enter()
    SFSpeechRecognizer.requestAuthorization { _ in
        group.leave()
    }
    group.wait()
}

let authorized = SFSpeechRecognizer.authorizationStatus() == .authorized
if !authorized {
    let helperName = (Bundle.main.bundleURL.lastPathComponent as NSString).deletingPathExtension
    fail(
        "Apple on-device ASR: Speech Recognition permission not granted. "
        + "Open System Settings → Privacy & Security → Speech Recognition and allow "
        + "\(helperName), then try again."
    )
}

// 4. Run on-device recognition.
let request = SFSpeechURLRecognitionRequest(url: audioURL)
request.requiresOnDeviceRecognition = true
request.taskHint = .dictation
request.shouldReportPartialResults = false

let semaphore = DispatchSemaphore(value: 0)
var transcriptText = ""
var errorMessage = ""

recognizer.recognitionTask(with: request) { result, error in
    if let result = result {
        let text = result.bestTranscription.formattedString
        if !text.isEmpty {
            transcriptText = text
        }
        if result.isFinal {
            semaphore.signal()
        }
    }
    if let error = error {
        if errorMessage.isEmpty {
            errorMessage = error.localizedDescription
        }
        semaphore.signal()
    }
}

semaphore.wait()

if transcriptText.isEmpty {
    if errorMessage.isEmpty {
        errorMessage = "recognition produced no transcript"
    }
    fail("Apple on-device ASR failed: \(errorMessage)")
}

print(transcriptText)
exit(0)
