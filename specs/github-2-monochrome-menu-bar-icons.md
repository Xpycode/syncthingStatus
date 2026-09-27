# Genuine Monochrome Menu Bar Icons (#2)

**Status:** Draft
**Created:** 2026-09-27
**Source:** [GitHub issue #2](https://github.com/Xpycode/syncthingStatus/issues/2)

## Problem

People who keep a monochrome macOS menu bar still see blue/colored syncthingStatus artwork. The existing **Monochrome** setting selects the classic state mapping, but the images themselves remain colored. The name therefore promises a visual result it does not provide.

## Proposed solution

Make **Monochrome** render true single-color menu bar images that follow the current macOS menu bar appearance. Keep the existing **Traffic-Light** option for people who prefer color. Preserve recognizable in-sync, active-sync, warning/unavailable, and error conditions through shape and accessible text, without relying on color.

The flow stays in Settings → Status Icon: select Monochrome or Traffic-Light, see the menu bar update immediately, and retain the choice after relaunch. Update the setting's help text to describe the actual behavior.

## Acceptance criteria

- [ ] Given Monochrome is selected, when the app displays any menu bar state, then the artwork contains no fixed blue, green, amber, or red pixels and follows the system's light/dark/selected menu bar treatment.
- [ ] Given the icon changes between in-sync, syncing, attention/unavailable, and error, when viewed without color, then the states remain distinguishable by silhouette or interior mark; the tooltip and accessibility title identify the current condition.
- [ ] Given syncing starts or stops, when the app updates its icon, then every static or animation frame uses the selected style without a colored flash.
- [ ] Given Traffic-Light is selected, when each state appears, then the existing colored visual semantics remain available.
- [ ] Given the user changes icon style, when the app updates or relaunches, then the chosen style is shown and persists.
- [ ] Given macOS changes appearance or the menu bar item is highlighted, when Monochrome is active, then the icon remains legible at normal menu bar size.
- [ ] Given an icon asset is missing, when a state is rendered, then the fallback remains legible and does not silently substitute a colored image in Monochrome mode.

## Technical considerations

- The current preference is `IconColorMode` in `SyncthingSettings.swift`; `StatusIconStateResolver` maps it to semantic state. `SyncthingStatusIcon.swift` loads PNG assets and explicitly sets `NSImage.isTemplate = false`. The rendering path must select appropriate monochrome assets and template treatment while retaining color assets for Traffic-Light.
- Review every static and active-sync image, including warning, error, connecting, and fallback paths. Do not change the status policy to make the visuals easier.
- Verify the final menu bar result in the supported macOS appearances at actual size. A pixel/asset check can catch fixed colors, while a native visual check establishes legibility and state distinction.
- This is an icon rendering and existing setting change; it does not introduce a new primary-window control or navigation pattern.

## Out of scope

- Changing the app's Dock icon or brand identity.
- Changing sync-state classification, notification rules, or refresh timing.
- Replacing the existing Traffic-Light preference.

## Open questions

| Question | Status | Working assumption |
|---|---|---|
| Should the current "Monochrome" preference remain the default? | Open | Yes; retain stored values and avoid a settings migration. |
| Should active transfer directions have distinct glyphs or one syncing glyph? | Open | Preserve current direction distinctions where they are actually displayed; at minimum keep syncing distinct from idle/error. |

## Related

- [Current task backlog](../docs/TASKS.md)
- [Status icon setting](../01_Project/syncthingStatus/SyncthingSettings.swift)
- [Menu bar renderer](../01_Project/syncthingStatus/SyncthingStatusIcon.swift)
