# Third-Party Audit

This audit documents the v0.3.11 self-contained release payload.

| Project / file / dependency | Source | Current use | License status | Risk | Recommendation |
| --- | --- | --- | --- | --- | --- |
| `bridge/src/vibe_stick/` | Project-authored Python | Local Mac bridge, state API, quota observation, recording flow, ASR adapter, paste injection | MIT under this repository | Low | Keep. |
| `app/macos/VibeStickHUD/main.swift` | Project-authored Swift | Minimal recording status HUD | MIT under this repository | Low | Keep. |
| `firmware/sticks3/src/` and `firmware/sticks3/include/` | Project-authored C using ESP-IDF APIs | StickS3 UI, HTTP, buttons, audio, battery, speaker alerts | MIT under this repository | Low | Keep. |
| `assets/brand/vibestick-icon.svg` | Project-generated simple geometry | Temporary VibeStick brand icon | MIT under this repository | Low | Keep until polished branding exists. |
| `assets/providers/**` and `firmware/sticks3/assets/providers/**` | Project-generated simple geometry | Temporary Codex status icon | MIT under this repository | Low | Keep. Avoid replacing with third-party brand marks unless license/brand usage is reviewed. |
| `firmware/sticks3/generated/vibe_stick_ui_assets.c/.h` | Generated from project-owned PNG icons | LVGL image descriptors for the Codex icon | MIT under this repository | Low | Keep. |
| `firmware/sticks3/generated/vibe_stick_cn_16.c` | Generated from Source Han Sans K Regular | LVGL Chinese glyph subset for StickS3 UI | Source font is SIL Open Font License 1.1, copyright Adobe 2014-2021 | Medium | Keep with NOTICE attribution. Do not use the reserved Source name as an VibeStick brand. |
| `firmware/sticks3/src/idf_component.yml` dependencies: `espressif/button`, `espressif/esp_codec_dev`, `lvgl/lvgl` | ESP Component Registry | Build-time firmware dependencies | External open-source components, not vendored after cleanup | Low | Keep dependency manifest and lock file. Review component licenses before binary release. |
| ESP-IDF framework | Espressif | Firmware framework | External SDK, used only on the release machine | Low | Keep as release build prerequisite. |
| `release/tools/esptool/**` | Espressif esptool v4.11.0 standalone binaries | Consumer-side ESP32-S3 probing and USB flashing | GPL-2.0; full license is bundled at `release/tools/esptool/LICENSE` | Medium | Keep both architectures and pinned SHA-256 values. |
| `tools/nvs/esp_idf_nvs_partition_gen/` | Espressif `esp_idf_nvs_partition_gen` v0.1.9 | Generate the per-install `vibe_cfg` image | Apache-2.0; SPDX copyright/license header retained | Low | Keep the unencrypted path dependency-free and retain upstream attribution. |
| `release/runtime/cpython-3.12.13-*.tar.gz` | `astral-sh/python-build-standalone` release `20260510` | Embedded, user-local Mac Bridge runtime | CPython and bundled libraries retain upstream licenses inside each archive; build project is MPL-2.0 | Medium | Keep both architectures and pinned SHA-256 values; audit archive notices before each version update. |
| OpenAI-compatible ASR API | Optional external service | Optional speech-to-text when configured | Service API, no source vendored | Medium | Document that audio leaves the Mac when a cloud ASR service is configured. Do not commit API keys. |
| Local Codex session files | User-local Codex data | Quota/status observation from `~/.codex/sessions/**/*.jsonl` | User-local data, not vendored | Medium | Keep local-only. Do not upload or commit session data. |
| Historical VoiceStick / StickS3VoiceKit / VoiceStickTrial directories outside this repository | Local historical reference directories in the parent workspace | Not part of VibeStick repository | Source/license uncertain from local copy | High | Do not copy into VibeStick. Do not publish as part of this repository. |
| Old provider logo-like assets removed during cleanup | Earlier local prototype assets | No longer used | Source unclear / brand risk | High | Replaced with simple project-generated temporary icons. |
| `firmware/sticks3/managed_components/`, `firmware/sticks3/build/`, Python `__pycache__/` | Generated local build/cache output | Not part of source | N/A | Low | Ignored by git. Do not commit. |
| `firmware/sticks3/include/vibe_stick_secrets.h`, `.env`, logs, recordings | Local user secrets/output | Runtime configuration and generated data | Private user data | High | Ignored by git. Never publish. |

## Summary

The self-contained installer intentionally vendors the two official esptool executables, two CPython runtime archives, and Espressif's NVS generator. Their versions, hashes, and license locations are documented above. The generated Chinese LVGL glyph subset remains derived from Source Han Sans K under the SIL Open Font License 1.1. Firmware component dependencies are resolved on the release machine through the ESP-IDF component manager.

Before a public binary release, review the exact ESP-IDF/component licenses included in the firmware image and ensure the Source Han Sans K attribution remains in NOTICE.
