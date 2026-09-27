# Homebrew Installation Follow-Through (#6)

**Status:** Draft — custom-tap scope confirmed by user on 2026-09-27
**Created:** 2026-09-27
**Source:** [GitHub issue #6](https://github.com/Xpycode/syncthingStatus/issues/6)

## Problem

Homebrew users asked for a cask and a documented install path. A custom tap now publishes the v1.6.2 cask, and its style, strict online audit, and public checksum-verified fetch passed. The full install/upgrade path has not yet been exercised without disturbing an existing app installation, and the reporter has not been told how to use the published cask.

## Proposed solution

Complete the custom-tap acceptance check in an isolated installation location, make the README installation and upgrade commands accurate, then reply to issue #6 with the supported commands and the difference from an official Homebrew cask listing. The user confirmed the custom tap is the target; an official catalogue submission is outside this issue's scope.

Current user flow:

```sh
brew tap xpycode/syncthingstatus https://github.com/Xpycode/syncthingStatus.git
brew install --cask xpycode/syncthingstatus/syncthingstatus
```

The request's example, `brew install --cask syncthing-status`, is not currently available from this custom tap without prior setup or an official cask listing. Do not advertise that exact command as working until it is independently verified.

## Acceptance criteria

- [x] Given the public custom tap, when a user loads the cask, then it resolves the published v1.6.2 Universal DMG and verifies its SHA-256 checksum. Recorded in [Homebrew distribution](../docs/homebrew.md).
- [x] Given a supported developer-tool setup, when the published cask is styled and strictly audited online, then both checks pass. Recorded on 2026-09-17.
- [ ] Given a clean, isolated Homebrew environment or disposable app destination, when the documented install commands run, then `syncthingStatus.app` installs with the expected bundle ID, version, signature, and notarization; the user's existing app stays untouched.
- [ ] Given an isolated v1.6.1 test installation and the published v1.6.2 cask, when the documented upgrade path runs, then Homebrew replaces the test copy with v1.6.2 while leaving the user's installed app untouched. If the disposable setup cannot faithfully exercise this, record the limitation and keep this check open.
- [ ] Given an existing manually installed app, when following the documented migration guidance, then Homebrew does not overwrite an unknown app; the supported `--adopt` path is verified or clearly marked unverified.
- [ ] Given the issue reporter reads README, when they follow Homebrew installation or upgrade instructions, then the exact published tap/cask names work and the custom-tap requirement is explicit.
- [ ] Given the tested distribution path, when replying to issue #6, then the reply links the commands and release, states the custom-tap limitation plainly, and closes the issue only if the chosen scope is satisfied.

## Technical considerations

- The cask is `Casks/syncthingstatus.rb` in this repository. It consumes the existing notarized GitHub release DMG; maintain the cask's version, digest, URL, app path, and minimum supported macOS with each public release.
- Preserve Sparkle in-app updates. Homebrew users must explicitly use the documented `brew upgrade --cask --greedy` path when they want Homebrew to upgrade an auto-updating cask.
- Installation and upgrade tests must avoid `/Applications/syncthingStatus.app` and the user's real settings, credentials, bookmarks, and Syncthing daemon. Use a disposable destination or account that actually exercises Homebrew's cask installation semantics.
- Homebrew's [tap documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap) supports custom cask taps; [official cask eligibility](https://docs.brew.sh/Acceptable-Casks) is a separate decision and process.

## Out of scope

- Installing or configuring the Syncthing daemon.
- Rebuilding or repackaging the app specifically for Homebrew.
- Claiming an official `homebrew/cask` listing before one exists.
- Replacing or relaunching the user's installed app for a test.

## Open questions

| Question | Status | Working assumption |
|---|---|---|
| Is the custom tap sufficient to resolve #6, or should the one-command official cask catalogue listing be pursued? | Resolved | User chose to finish the custom tap on 2026-09-27; treat an official listing as a separate proposal. |
| What disposable Homebrew destination/account best verifies install and future upgrade on this Mac? | Open | Choose a method that leaves the current installed app and user data untouched. |

## Related

- [Homebrew distribution and validation](../docs/homebrew.md)
- [Current cask](../Casks/syncthingstatus.rb)
- [README installation commands](../README.md#install-with-homebrew)
