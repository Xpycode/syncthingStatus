# Homebrew distribution

The repository doubles as a custom Homebrew tap through `Casks/syncthingstatus.rb`.
It distributes the existing notarized GitHub release DMG; no app rebuild or separate
tap repository is required. This is not a listing in Homebrew's official cask catalogue.

## Installation after publication

These commands require the cask to be published on this repository's default branch:

```sh
brew tap xpycode/syncthingstatus https://github.com/Xpycode/syncthingStatus.git
brew install --cask xpycode/syncthingstatus/syncthingstatus
```

If Homebrew requests trust for this custom tap, follow its prompt for this cask.
The app requires macOS 15.5 or later and supports Intel and Apple Silicon. Homebrew's
macOS dependency names the Sequoia release; the cask caveat and app bundle retain the
more precise 15.5 minimum.

Syncthing must be configured and running separately, locally or on another machine.
The cask does not install, start, stop, or reconfigure the Syncthing daemon. Existing
manual app installations may need Homebrew's `--adopt` option if the installed app
matches the release; quit the app first. Do not use `--force` to overwrite an unknown
installation.

Sparkle updates remain enabled. To request an upgrade through Homebrew despite the
app's built-in updater:

```sh
brew update
brew upgrade --cask --greedy xpycode/syncthingstatus/syncthingstatus
```

Normal uninstall preserves app settings, API credentials, and folder access grants.
No `zap` action is supplied because these contain configuration worth retaining.

## Release maintenance

1. Publish the notarized and stapled DMG as a GitHub release asset.
2. Download that exact public asset and calculate `shasum -a 256`.
3. Update `version` and `sha256` in `Casks/syncthingstatus.rb`; confirm the URL and
   `syncthingStatus.app` name still match the archive.
4. Validate through a local tap with `brew style`, `brew audit --cask --online
   --strict`, and `brew fetch --cask`; inspect the downloaded app's architecture and minimum OS.
5. Commit and publish the cask update. The production appcast must also continue to
   reference only already-published DMGs.
6. Verify the public tap can fetch and install the new release, using a temporary
   app directory when an existing installation must be preserved.

## References

- [Homebrew: creating and maintaining a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew: cask cookbook](https://docs.brew.sh/Cask-Cookbook)

## Initial validation (2026-09-05)

- GitHub latest release: v1.6.1; the local release DMG matches GitHub's published
  SHA-256 digest `b5f2475772164f2807fdba7256bc812562ab74813e6c89b85c3d9dc3d6835422`.
- Local exported app: `arm64` and `x86_64`, minimum macOS 15.5.
- Homebrew 6.0.20: cask metadata loaded successfully; style check passed with no
  offenses; `brew fetch --cask` downloaded and checksum-verified the public DMG.
- Downloaded DMG mounted read-only: expected app path, bundle ID, version 1.6.1,
  build 163, macOS 15.5 minimum, both architectures, strict code-signature verification,
  and stapled notarization-ticket validation all passed.
- Full `brew audit --cask --online --strict` stopped during environment setup:
  installed Xcode 26.6 is below Homebrew's required 27.0 on this Mac. Re-run on a
  supported developer-tool setup. No app source build was needed or attempted.
- Public-tap publication: pending. Full Homebrew installation was not run against
  the existing app installation.
