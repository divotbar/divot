---
id: "0044"
title: Signed and notarized DMG with Developer ID (blocked on the maintainer's Apple certificate)
type: feature
status: inbox
needs_input: true
needs_input_reason: needs-human-step
needs_input_detail: "Acceptance criteria mention a real device, physical hardware, accounts, credentials, or third-party registration — split that verification into a separate human-only task. (matched: credentials or keys)"
priority: p2
area: [macos, docs]
depends_on: ["0041"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T12:47:11Z"
updated_at: "2026-10-11T12:47:11Z"
---
## Problem

The unsigned DMG triggers Gatekeeper warnings. The maintainer has a paid Apple Developer account and wants a signed, notarized DMG.

## Desired UX

- Release builds are signed with a Developer ID Application certificate and notarized, so they open without warnings.
- The release notes and install page drop the unsigned workaround.

## Acceptance criteria

- Signing and notarization run in the release workflow with credentials in GitHub secrets (certificate, password, Apple ID or API key). No credentials in the repo.
- The notarized DMG passes `spctl --assess` locally.
- The install page (#0042) and the Homebrew cask (if added) are updated to the signed build.
- `repoos check` passes.

## Notes for AI

BLOCKED on the maintainer: needs the Developer ID certificate exported and the notarization credentials added as GitHub secrets. Do not start until the maintainer confirms the secrets exist.

## Activity

- 2026-10-11T12:47:11Z · created · njachowski@gmail.com
- 2026-10-11T12:47:11Z · needs_input
