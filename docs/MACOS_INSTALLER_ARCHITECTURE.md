# macOS Installer Architecture

## Product goal

VibeStick Setup should take a new StickS3 from USB connection to a verified, working VibeStick without asking the user to edit source files or use Terminal.

## Self-contained release

The current SwiftUI app embeds a minimal clean project template and installs it into a stable,
writable `~/Library/Application Support/VibeStick/InstallerProject` workspace. It never scans the
app bundle's parent checkout, and template updates preserve the workspace's `.env` and firmware
secrets. Its normal UI is a single three-step
wizard—network, alert volume, and optional cloud voice input, device connection, then automatic installation. The installed menu-bar app preserves three runtime choices: cloud API, local Whisper, and WeChat Input. Serial
metadata, model endpoints, diagnostics, and raw logs are available only as advanced or technical
details.

Under that simple flow it:

1. Validate and atomically save Wi‑Fi, Bridge, StickS3 alert-volume, and cloud ASR configuration, then verify the API key and model with a one-second silent transcription request. Local Whisper and WeChat Input require no API test.
2. Keep reusable secrets in a versioned macOS login-Keychain namespace while writing the runtime files required by the existing firmware and Bridge. Startup reads disallow authentication UI, and local packaging prefers an available Apple Development identity so rebuilds keep a stable code-signing identity. A release may opt into the Data Protection backend with the proper entitlement.
3. Discover serial devices and stable USB identity through IOKit.
4. Install the embedded, checksum-verified Python 3.12 runtime and precompiled HUD/menu-bar apps. Consumer Macs do not need Xcode Command Line Tools, Git, ESP-IDF, or system Python.
5. Validate the signed release assets, generate a temporary `0600` `vibe_cfg` NVS image, install the Bridge, re-check the selected USB identity, flash the prebuilt images, explicitly start the StickS3, and require a fresh authenticated heartbeat carrying this deployment's nonce before diagnostics pass. When the app and partition table already match, only `vibe_cfg` is rewritten.
6. Stream bounded, redacted logs, allow cancellation of the whole child process group, and retain a non-secret recovery journal if flashing is interrupted.

The app uses native SwiftUI with separate Core and Platform targets so validation, redaction, parsing, and repository writes can be tested without launching the UI.

Every release rebuilds the self-contained app and refreshes the versioned managed template while preserving `.env` and firmware secrets. Repository, bundled-template, and managed-template copies of changed deployable files must match before tagging. The installer is the supported path for both Mac deployment and firmware flashing.

## Public distribution

The release payload includes:

- a Developer ID signed and notarized `.app`/DMG;
- an embedded, signed manifest describing hardware, flash offsets, firmware version, hashes, and minimum installer version;
- precompiled StickS3 bootloader, partition table, application, and other fixed images;
- a generated NVS image for Wi‑Fi host/token values, so user configuration does not require recompiling firmware;
- architecture-matched official standalone `esptool` binaries and an embedded NVS generator, with fixed flash operations and strict device identity checks;
- precompiled HUD and menu-bar apps plus an architecture-matched embedded Python runtime for the Bridge;
- post-flash verification tied to a fresh device heartbeat and the expected firmware build;
- explicit recovery instructions if USB is disconnected during flash.

With that design, an end user needs only the app, a USB-C data cable, Wi‑Fi credentials, and an optional ASR API key. Git, a source checkout, Xcode tools, and the roughly 1 GB ESP-IDF install disappear from the normal path.
