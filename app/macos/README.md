# VibeStick macOS Developer Notes

This document covers development and delivery details for the macOS apps. For normal installation, see the root [README](../../README.md).

This directory contains two separate macOS components:

- `VibeStickSetup` is the native SwiftUI setup app. Its three-step wizard collects Wi‑Fi, StickS3 alert-volume, and optional cloud voice-input settings, verifies bundled release assets, generates a private NVS configuration image, flashes universal firmware, installs prebuilt Bridge/menu-bar components, and verifies the result.
- `VibeStickHUD` is the small AppKit recording-status overlay installed with the Bridge LaunchAgent.

## Run the setup app

VibeStickSetup is a SwiftPM app that requires macOS 14 or newer:

```sh
./script/build_and_run.sh
```

The script builds firmware once on the release machine, builds `app/macos/Package.swift` plus the HUD/menu-bar payloads, embeds both esptool architectures and both compressed Python runtimes, and stages the app at `dist/VibeStickSetup.app`. It prefers a Developer ID Application identity, then Apple Development, and falls back to an ad-hoc signature.

For a release artifact, use `./script/build_and_run.sh --package`. It creates a hardened-runtime universal app and `dist/VibeStickSetup-<version>.dmg`. A Developer ID Application certificate and notarization credentials are still required before public distribution.

Run its tests with:

```sh
swift test --package-path app/macos
```

## Release discipline

Every delivered change increments the shared patch version across Bridge, firmware, Setup, installed menu-bar About text, and installer metadata. Run `./script/build_and_run.sh build`, launch the resulting installer to refresh its managed `InstallerProject`, and verify changed deployable files match across the repository, bundled template, and managed template. Template refresh must preserve `.env` and `vibe_stick_secrets.h`; both Mac installation and firmware flashing are performed through this installer.

## Current delivery boundary

The built `.app` is self-contained. It carries a versioned firmware manifest, universal firmware, standalone esptool binaries, compressed Python runtimes, a standard-library-only NVS generator, and precompiled Mac payloads. First launch copies the signed template to `~/Library/Application Support/VibeStick/InstallerProject` while preserving `.env` and the private configuration header. Consumer installation performs no compilation or dependency download.

The app never writes secrets to UserDefaults. Wi‑Fi and the local Bridge token are converted to a temporary `0600` NVS image and deleted after flashing; ASR credentials remain Mac-only in `.env` and the login Keychain. Technical logs remain bounded and redact managed secrets. Only a non-secret interrupted-flash recovery flag is kept in UserDefaults.
