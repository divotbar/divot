---
id: "0042"
title: Update the landing and docs with install instructions for the DMG
type: feature
status: active
priority: p1
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/update-the-landing-and-docs-with-install
created_at: "2026-10-11T12:47:05Z"
updated_at: "2026-10-12T13:40:16Z"
review_rounds: 1
review_passes: 1
---
## Problem

The site doesn't tell users how to get the app. Once the release exists, it should link to the latest DMG and explain the first launch.

## Desired UX

- A Download / Install page with a button to the latest DMG on the GitHub Release.
- First-launch steps for the unsigned build (right-click, Open, then allow in Privacy & Security if needed) and the Accessibility permission steps.
- The landing page links to the install page.

## Acceptance criteria
- Add site/guide/install.md: the download link, checksum note, first launch steps for the unsigned build, the Accessibility (and Location for the Wi-Fi name) setup, the Homebrew command (brew install --cask divotbar/tap/divot) and the AI-setup pointer (site/guide/ai-setup.md).
- No release exists yet (no tag, no GitHub Release). Until one does, the page must say plainly that the first release is not published yet and show no download button or invented version/checksum. Use one clearly named flag or constant so flipping it to 'released' is a one-line follow-up, and use only the stable https://github.com/divotbar/divot/releases/latest URL when released.
- Link it from the landing page and the sidebar.
- Public copy distinguishes implemented from planned behaviour; no notarization claims.
- The page builds with bun run check / bun run build; repoos check passes.

## Notes for AI

Depends on the unsigned DMG release task. Do not promise signed or notarized builds yet.

## Shots
```json
[
{
"label": "Install guide: first release not published, no download button",
"target": "website",
"route": "/guide/install",
"highlight": ".install-pending"
},
{
"label": "Landing page links to the install guide",
"target": "website",
"route": "/",
"highlight": "a[href=\"/guide/install\"]"
}
]
```

## Activity

- 2026-10-11T12:47:05Z · created · njachowski@gmail.com
- 2026-10-12T13:23:45Z · body: section Acceptance criteria
- 2026-10-12T13:23:46Z · status inbox→ready
- 2026-10-12T13:23:46Z · status ready→active, branch
- 2026-10-12T13:27:53Z · body: section Shots
- 2026-10-12T13:29:40Z · status active→review
- 2026-10-12T13:30:44Z · note: review pass 1: needs some work
- 2026-10-12T13:30:44Z · status review→active
- 2026-10-12T13:40:16Z · message_queued at 2026-10-12T13:40:16.047Z
- 2026-10-12T13:40:16Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
