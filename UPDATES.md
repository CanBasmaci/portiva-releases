# Manual releases

Portiva 0.6.1 uses manual DMG downloads from GitHub Releases:
https://github.com/CanBasmaci/portiva-releases/releases/latest

The app contains no Sparkle updater, update feed, automatic check or download.
Quit Portiva after disconnecting all sessions, download the latest DMG and replace
Portiva in Applications. The existing bundle identifier preserves preferences;
connection profiles and commands remain in Application Support/Portiva.

Build with scripts/package.sh, verify the DMG and publish it with release notes
and SHA256SUMS.txt. The historical scripts/prepare-update.sh is retired.
Apple Development signing is used; this build is not Developer ID signed or notarized.
