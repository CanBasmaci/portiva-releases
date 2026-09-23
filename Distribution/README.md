# Apple distribution status

The user confirmed on 2026-09-23 that the Apple account is free (not enrolled in the paid Apple Developer Program). The available identity is Apple Development; there is no Developer ID Application identity. Therefore notarization cannot currently be submitted/completed. No Apple approval or notarization is claimed.

After membership is active:
1. Create/install a Developer ID Application certificate and its private key using the account holder's Apple developer account.
2. Set up notarytool credentials locally in Keychain. Do not put passwords/API private keys in this repository or chat.
3. Run scripts/notarize.sh with DEVELOPER_TEAM_ID and NOTARY_PROFILE set. The script archives, exports, submits to Apple, requires Accepted, staples, and validates the app before producing the final ZIP.
4. Package and verify the notarized app, then publish the installer and checksums to GitHub Releases. Updates are downloaded manually.

The script is syntax checked but its Apple submission path cannot be executed until the membership, certificate and credentials are available.

References:
https://developer.apple.com/developer-id/
https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
