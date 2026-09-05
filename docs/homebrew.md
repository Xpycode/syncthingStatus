# Homebrew distribution

The repository doubles as a custom Homebrew tap through `Casks/syncthingstatus.rb`.
It distributes the existing notarized GitHub release DMG; no app rebuild or separate
tap repository is required. This is not a listing in Homebrew's official cask catalogue.

## Installation

The cask is published on this repository's default branch:

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

For each **public app release**, keep GitHub, Sparkle, Homebrew, and the website on
the same version. Ordinary source or documentation edits can be committed and pushed
without cutting a release or changing the cask and website.

There is one app build and one release DMG. Homebrew downloads that GitHub asset;
publishing its cask means pushing a small metadata change to this same repository.
There is no separate Homebrew binary upload. These updates are currently manual;
a source push alone does not update the cask, appcast, or website.

1. **Prepare and validate:** bump app version/build, update release notes, run
   `/check ship`, and build, sign, notarize, and staple the release DMG. Commit and
   push the release source; tag the corresponding commit.
2. **GitHub release:** publish that version's DMG and release notes. Verify the
   public asset URL works before announcing it through any update channel.
3. **Sparkle and Homebrew:** update `appcast.xml` with the release URL, version/build,
   EdDSA signature, and byte length. Download the published DMG, calculate
   `shasum -a 256`, and update `version` and `sha256` in `Casks/syncthingstatus.rb`.
   Confirm its URL and `syncthingStatus.app` path. Run cask style, audit, and fetch
   checks, then commit and push both metadata updates to `main`.
4. **Website:** in the App-Websites project, update the syncthingStatus page,
   catalogue `apps.json` version/release date, release notes, and any hosted download
   or download link; deploy the site. Preserve any still-relevant upgrade caveats.
5. **Verify live:** check the GitHub asset, Sparkle update feed, Homebrew tap and
   install/upgrade flow, and website all serve the intended release. Use a temporary
   app directory for installation checks when preserving an existing installation.
   Record results and any validation limits in the session log and project state.

Cask validation commands: `brew style Casks/syncthingstatus.rb`,
`brew audit --cask --online --strict xpycode/syncthingstatus/syncthingstatus`, and
`brew fetch --cask xpycode/syncthingstatus/syncthingstatus`. Test changed cask metadata
through a local tap before publishing. The live root `appcast.xml` must never contain
draft URLs or signatures: the referenced DMG must already be public.

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
- Published to `main`; a fresh tap from the public GitHub URL loaded v1.6.1 and
  `brew fetch --cask` verified the release successfully. Temporary validation taps
  were removed and Homebrew developer mode restored to off.
- Full Homebrew installation was not run against the existing app installation.
