# VibeStick delivery rules

These rules are mandatory for every product change in this repository.

1. Increment the VibeStick patch version for every delivered update. Keep the
   Bridge version, StickS3 firmware version, installer version, installed
   menu-bar version, and visible About version in sync.
2. The self-contained macOS installer is the only supported deployment path.
   Do not hand-copy Bridge, helper, menu-bar, or firmware files into their
   installed locations as the final delivery step.
3. Every firmware, Bridge, helper, menu-bar, configuration, or installer change
   must be followed by rebuilding `dist/VibeStickSetup.app` with
   `script/build_and_run.sh build`.
4. Launch the rebuilt installer so its versioned template refreshes
   `~/Library/Application Support/VibeStick/InstallerProject`. The refresh must
   preserve `.env` and `firmware/sticks3/include/vibe_stick_secrets.h`.
5. Before declaring work complete, verify that the repository, the installer's
   bundled `Contents/Resources/VibeStickProject`, and `InstallerProject` contain
   identical versions of every changed deployable source file.
6. Firmware flashing and Mac software installation must be performed through
   the rebuilt installer. Direct build, copy, or flash commands may be used for
   development diagnostics, but they do not count as deployment or completion.

