# Release assets

This directory contains the pinned offline resources used to build the self-contained VibeStick installer, plus the installation and release notes shipped with the v0.3.11 download.

- `runtime/`: pinned arm64 and x86_64 Python 3.12 runtime archives.
- `tools/`: pinned arm64 and x86_64 ESP32-S3 flashing tools and license.
- `assets.sha256`: source checksums for the pinned runtime and flashing-tool assets.
- `INSTALL.zh-CN.md` and `INSTALL.en.md`: end-user installation instructions.
- `RELEASE_NOTES-v0.3.11.md`: release summary.

The downloadable `VibeStickSetup-0.3.11-macOS-arm64.zip` is published as a GitHub Release asset rather than committed as a second copy of the approximately 69 MB application bundle. Its matching `.sha256` file is published alongside it.

The current package is ad-hoc signed and not Apple-notarized. A public notarized universal DMG requires a Developer ID Application identity and a configured `VIBE_STICK_NOTARY_PROFILE`.
