# Portiva 0.6.1

Native macOS Swift/SwiftUI serial and SSH console. Graphite–amber theme. macOS 13+, Apple Silicon and Intel.

## Features

- USB/serial ports refresh automatically; baud is entered manually.
- 5–8 data bits, None/Even/Odd parity, 1–2 stop bits, None/RTS-CTS/XON-XOFF flow control.
- SwiftTerm 1.19.0 VT/xterm terminal: direct typing, arrow keys, Tab, Escape, Ctrl keys, ANSI colors, cursor movement, alternate screen, Unicode, copy/paste, and 5000-line scrollback.
- The terminal follows new output when at the bottom; scroll up to read older output. Use the down-arrow control to return to the bottom.
- Optional command input with CR/LF/CRLF, plus an explicit Ctrl-C button. Direct terminal Enter uses normal terminal keyboard encoding.
- Portiva > Settings (⌘,) or sidebar Settings opens privacy/font preferences.
- “Komut / parola alanındaki yazıyı gizle” masks the optional input field. This setting persists; the draft is cleared when switching privacy mode, sending, or disconnecting. No command/password history is saved. Native terminal input has no local echo. Output echoed by the device is not redacted.
- Manual DMG downloads from GitHub Releases. No automatic update checks or in-app updater.

The serial link has no standard screen-size negotiation: resizing changes the local terminal, not switch configuration. Vendor-specific commands are not injected. Telnet and USB drivers are outside this release.

## Installation / development

See INSTALL.txt. Open Portiva.xcodeproj in Xcode, select Portiva / My Mac, choose your own signing team in Signing & Capabilities, and run.
The project retains com.can.CanSerial as the bundle identifier to preserve preferences. The application and project names are Portiva. Do not open legacy CanSerial and Portiva against the same port.

Current personal builds use the existing Apple Development certificate. The user confirmed a free Apple account; Developer ID distribution and notarization are blocked until paid membership, a Developer ID Application certificate, and notary credentials are available. See Distribution/README.md. No notarization is claimed.

## Build and test

```sh
xcodebuild -skipPackagePluginValidation -project Portiva.xcodeproj -scheme Portiva -configuration Release -derivedDataPath build build
xcrun swiftc Portiva/SerialConnection.swift Tests/main.swift -o /tmp/portiva-serial-tests
/tmp/portiva-serial-tests
./scripts/package.sh
```

SwiftTerm 1.19.0 has a build-info plugin. Its pinned source was reviewed: it reads its package's Git metadata and writes a generated Swift constants file. The CLI build allows this plugin for the invocation; no global Xcode trust preference is changed. When opening Xcode, trust the pinned SwiftTerm build plugin if prompted. Xcode's official Metal Toolchain component is required to compile SwiftTerm's shaders.

Tests/main.swift verifies actual PTY reads/writes, reconnect/reset, and all 72 framing/flow combinations.
Tests/Terminal/main.swift exercises the native terminal adapter through a PTY, progress rewriting, split ANSI sequences, Unicode, backspace, alternate screen, keyboard control bytes, clearing, and absence of local input echo.

Real hardware: the user confirmed successful VLAN configuration on Aruba 6100 with the earlier Portiva build. Re-test the new terminal engine on hardware after installation.

## Distribution

scripts/package.sh builds a local DMG with a version derived from the app.
scripts/prepare-update.sh is retired; distribute the DMG with SHA256SUMS.txt.
scripts/notarize.sh is ready for the paid Developer ID workflow; it fails early without the necessary identity. Apple submission has not been executed.

UPDATES.md describes manual installation from GitHub Releases.

Third-party licenses are included in Portiva/ThirdPartyNotices.txt and the application resources.

## Previous verification of 0.5.0

Release build succeeded for arm64 and x86_64. The serial PTY suite and native terminal integration suite passed, including ANSI cell-color checks and exact keyboard bytes. The Settings toggle was tested in the running app: it switches the input to a secure text field, survives relaunch, and switches back. Settings layout was visually checked. Run `BUILD_ROOT=/path/to/derived-data ./scripts/test.sh` after a Release build to repeat the automated checks.

## Added in 0.6.0

- Independent session tabs, close confirmation, duplicate serial-port protection, disconnection banner and explicit reconnect.
- Local connection profiles and command library in Application Support/Portiva/library.json, atomic writes and 0600 permissions. Passwords are not stored. Last connection settings are remembered.
- SSH through macOS OpenSSH and a pseudo-terminal. Host-key confirmation and authentication happen in the terminal. The connection indicator means the SSH process is running, not that authentication has succeeded. OpenSSH user configuration applies.
- Multiline paste preview with the target shown, control-character filtering, 64 KB cap, 200 ms pacing, cancellation and stale-session protection. Commands do not wait for device prompts. Use interactive commands separately. Multiline paste is blocked in private-input mode.
- Optional received-output logging. Private input and recognized password prompts pause recording; resume is explicit. This is not universal secret redaction: configurations printed by a device can contain secrets. Exports and the manually saved command library can also contain sensitive content.
- Configuration text comparison, UTF-8 import (1 MB/5000 lines per side), terminal snapshots and diff export.
- Optional Aruba AOS-CX, Cisco IOS/IOS-XE and Juniper Junos read-command shortcuts for VLAN, interface and MAC information. Every query is previewed before sending; output remains in the terminal. Other devices use Generic. No brand baud preset is imposed.

Tests/Workspace/main.swift covers persistence, corrupt-file preservation, SSH argument validation, log privacy, diffs, two live serial PTYs, duplicate-port prevention, exact batch framing, cancellation, stale previews and disconnect handling. SSH startup/failure is tested against loopback; authenticated SSH and all vendor command variants still require device testing.

## Verification of 0.6.0

Release build and all three automated suites passed. The running UI was checked for SSH fields, new session tabs, and configuration comparison (one added/one removed line). The DMG checksum and app code signature passed verification. The historical 0.6.0 update ZIP and appcast were verified before the updater was retired. The 0.6.1 installer is published on GitHub Releases. Authenticated SSH and vendor-specific queries require real-device validation.

## 0.6.1

Removed Sparkle, its menu and feed settings. Distribution uses manual DMG downloads. Historical 0.6.0 update-archive verification above describes the older build only.
