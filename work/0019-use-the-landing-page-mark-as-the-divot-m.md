---
updated_at: "2026-10-10T02:29:52Z"
review_passes: 1
id: "0019"
title: Use the landing-page mark as the Divot menu bar icon
type: chore
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/use-the-landing-page-mark-as-the-divot-m
created_at: "2026-10-10T02:10:26Z"
---
## Problem

The Divot menu bar item uses the SF Symbol `rectangle.topthird.inset.filled` (`macos/Sources/DivotApp/DivotAppDelegate.swift`, `installStatusItem`). The website and landing page use the custom mark in `site/public/mark.svg`, which the maintainer prefers.

## Desired UX

The menu bar item shows the same mark as the landing page, drawn as a template image so it follows the light and dark menu bar.

## Acceptance criteria

- Ship the mark as a template `NSImage` (vector or @1x/@2x PNG) in the app bundle resources, with the same proportions as the landing page.
- `installStatusItem` uses it, with `isTemplate = true` so it adapts to the menu bar appearance.
- The SF Symbol is removed or kept only as a fallback if the asset cannot load.
- `repoos check` passes. Do not claim a human checked the look.

## Notes for AI

The landing mark is a rounded square with a cream fill and a teal glyph. For a template image the fill must be dropped and only the glyph kept as an alpha mask, so check that the shape still reads at menu bar size.

## Activity

- 2026-10-10T02:10:26Z · created · njachowski@gmail.com
- 2026-10-10T02:24:58Z · status inbox→ready
- 2026-10-10T02:24:59Z · status ready→active, branch
- 2026-10-10T02:29:18Z · status active→review
- 2026-10-10T02:29:18Z · note: shots: skipped — the diff (7 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T02:29:52Z · note: review pass 1: good to go

