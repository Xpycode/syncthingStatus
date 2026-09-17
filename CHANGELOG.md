# Changelog

## [1.6.2] — 2026-09-17

### Fixed
- Long folder names and paths no longer squeeze file counts and sync status into unreadable columns or stretch folder rows in the menu bar dropdown ([#5](https://github.com/Xpycode/syncthingStatus/issues/5)).
- Folder names and paths truncate within the available space, with full text on hover. Pending-work summaries use at most two lines, with the full summary on hover.

### Security
- Temporarily disabled stuck-deletion cleanup because an existing folder-selection issue could delete from the wrong folder. Monitoring and stuck-deletion alerts remain available.

## [1.6.1] — 2026-08-10

### Fixed
- Enabled Sparkle's sandboxed installer so in-app updates can install successfully.
- Allowed Syncthing's self-signed HTTPS certificate for loopback connections only; remote HTTPS remains certificate-validated.
- Preserved the connected Syncthing version in About when a background refresh is cancelled.

### Upgrade note
- Users on v1.6.0 or earlier need one manual download because those versions cannot launch the update installer. Updates from v1.6.1 onward support in-app installation.

Earlier release history is preserved in the [README](README.md) and [GitHub releases](https://github.com/Xpycode/syncthingStatus/releases).

[1.6.2]: https://github.com/Xpycode/syncthingStatus/releases/tag/v1.6.2
[1.6.1]: https://github.com/Xpycode/syncthingStatus/releases/tag/v1.6.1
