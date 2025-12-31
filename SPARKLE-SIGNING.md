# Sparkle Update Signing

## Private Key Location

The Sparkle EdDSA private key is stored in the macOS Keychain:

- **Keychain**: `~/Library/Keychains/login.keychain-db`
- **Account**: `ed25519`
- **Label**: `Private key for signing Sparkle updates`
- **Created**: 2025-12-31

## Public Key

The corresponding public key (embedded in Info.plist):

```
eH6joIk0G+i5Hur25e/9B4hF3jN8q5lBqXzMxuOfcxw=
```

## Signing Updates

To sign a new DMG release:

```bash
# Path to sign_update tool (via Sparkle SPM package)
/Users/sim/Library/Developer/Xcode/DerivedData/syncthingStatus-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update /path/to/syncthingStatus-vX.X.dmg
```

This outputs the `sparkle:edSignature` and `length` values for appcast.xml.

## Key History

| Date | Event |
|------|-------|
| 2025-12-02 | Original key generated (not persisted to Keychain) |
| 2025-12-31 | New key generated after original was lost |

**Note**: v1.5 users cannot auto-update to v1.5.1 due to key change. Manual download required for that transition only.
