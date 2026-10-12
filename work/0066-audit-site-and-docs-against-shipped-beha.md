---
id: "0066"
title: Audit site and docs against shipped behaviour
type: chore
status: active
priority: p1
area: [docs, web]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/audit-site-and-docs-against-shipped-beha
created_at: "2026-10-12T11:40:14Z"
updated_at: "2026-10-12T12:01:21Z"
---
## Problem
Many features landed on 2026-10-11/12 (split date/time, chips, spacing and right inset, charging colour, keep-awake cup, Wi-Fi name and Location, Appearance item, native icon sizes). Docs were updated per task, so drift is likely in the guide pages, getting-started, roadmap, troubleshooting and the landing page.

## Desired UX
- Every page under site/ and docs/ matches current main: settings, defaults, item list, spacing, permissions (Accessibility, Location), install state.
- Roadmap lists only what is truly planned; nothing planned is described as shipped; no invented release links or availability.

## Acceptance criteria
- A list in the task of every page checked and each fix made; bun run check passes.
- Tahoe editorial direction and licence/credit rules in AGENTS.md respected.

## Notes for AI
Compare against the code and docs/configuration.md. Do not touch install/download copy (#0042 owns that).

## Audit log
Audited every page under `site/` and `docs/` against current `main` (code,
`docs/configuration.md`, `site/reference/configuration.md`, `examples/`, and the
task records for #0018/#0030–#0061). Fixes are grouped by page.

### Public site (`site/`)

- `guide/widgets.md` — rebuilt the built-in item table: split the combined
`clock` into `date` (off by default) and `time` (default right group), added
`appearance`; noted the green charging bolt badge versus the keep-awake cup;
permissions now state the launch Accessibility prompt and the Location-denied
message/pane link; click behavior now covers `date`/`time` and the appearance
toggle.
- `guide/getting-started.md` — default right group is `battery, time, network,
volume` (was "clock").
- `guide/customization.md` — `examples/focus.json` described as a minute *time*
(was "minute clock without the day of week").
- `guide/themes.md` — focus preset now uses `date`/`time` (was the legacy
`clock` item and `widgets.clock` options).
- `guide/workspaces.md` — default status group now battery, minute time,
network, volume; date called optional.
- `guide/performance.md` — reference workload and "use a minute time" wording.
- `guide/roadmap.md` — provider list uses date/time; "Proposed JSON
configurations" corrected to versioned examples with the parser/store/settings
implemented; shipped list now names the date/time split and the Appearance
bar item.
- `guide/build.md` — built-in provider list uses date/time.
- `guide/troubleshooting.md` — added "The Wi-Fi network name doesn't appear"
(Location permission and the denial path).
- `contributing/index.md` — delivered provider list uses date/time.
- `reference/configuration.md` — appearance item behavior added to the item
list; `layout.height` default now documented as the per-display native
menu-bar band (camera-housing top on notched, native bar height on
notch-free) with `32` as the fallback (#0045).
- `.vitepress/theme/components/BarPreview.vue` + `.vitepress/theme/style.css` —
split the demo clock into separate date and time spans to match the split.
- Checked, no change needed: `index.md`, `.vitepress/config.ts`,
`.vitepress/theme/Landing.vue`, `Layout.vue`, `index.ts`, `credits.md`
(licence/credit text unchanged and accurate).

### Engineering context (`docs/`)

- `configuration.md` — appearance item behavior added; `layout.height` default
documented as the per-display native menu-bar band with the `32` fallback.
- `roadmap.md` — date/time provider names; item 4 now records the Appearance
bar item (task 0037) as implemented.
- `architecture.md` — provider tree/item list uses date/time/appearance; time
wakes at the minute boundary and date at the day boundary.
- `product-requirements.md` — date/time; the Appearance bar item added to the
MVP table and the current-implementation list; "proposed JSON examples" →
"versioned".
- `local-preview.md` — default bar described as time + optional date; appearance
item added to the defaults and the click checklist.
- `performance.md` — default-workload and scenario/harness wording uses
date/time.
- `accessibility-physical-checks.md` — VoiceOver item list and actions include
`date`, `time`, and the appearance toggle.
- `handoff-2026-10-12-1607.md` — the #0054 spacing decision is annotated as
superseded by #0060 (8pt between items, 17px fixed right-edge inset).
- `evidence/0004`, `evidence/0007`, `evidence/0014` — dated records annotated
that they predate the #0033 date/time split; historical observations left
intact rather than rewritten.
- Checked, no change needed: `README.md`, `infrastructure.md`,
`bootstrap-status.md` (dated bootstrap snapshot), `adr/0001-native-appkit.md`,
and the other evidence files (dated records of past runs).

### Verification

`bun run check` and `REPOOS_CHECK_CHANGED=main repoos check` pass (site build
with dead-link checks, config/validator tests, 618 native tests, packaged-app
smoke test). No install/download copy was touched (#0042 owns it).

## Shots
```json
[
{
  "label": "Landing bar preview with split date and time items",
  "target": "default",
  "route": "/",
  "highlight": ".demo-time"
}
]
```

## Activity

- 2026-10-12T11:40:14Z · created · njachowski@gmail.com
- 2026-10-12T11:40:16Z · status inbox→ready
- 2026-10-12T11:55:20Z · status ready→active, branch
- 2026-10-12T12:00:51Z · body: section Audit log
- 2026-10-12T12:01:21Z · body: section Shots
