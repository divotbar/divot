# Set up Divot with your AI

::: info Implemented in source, not yet a download
The `divot` command line and its `config`, `items`, `theme`, and `status` subcommands are implemented in this repository and exercised by its checks. No signed or notarized build is published yet, so point your agent at a [local build](./build) or the in-source executable. The commands edit `~/.config/divot/config.json` directly — there is no daemon and no network API.
:::

Divot is small enough to configure by hand, but it is also built to be driven by an agent. Every setting is discoverable as JSON, every edit validates through the same parser the app uses, and the running app picks up a valid change without a restart.

## The copy-paste prompt

Paste the block below into your coding agent. It tells the agent to read the contract before it changes anything and which commands to prefer.

```text
You are helping me configure Divot, a native macOS menu-bar bar. The app reads
and watches ~/.config/divot/config.json (version 2) and applies a valid change
without a restart.

Before you change anything, read the contract:
  divot config schema --json    # every setting: key, type, range, default, writable
  divot status --json           # app version, running state, permissions, adapter, config

Then prefer the focused helpers for the two most common edits:
  divot items list --json
  divot items add <item> [--side left|right] [--at <index>]
  divot items remove <item>
  divot items move <item> [--side left|right] [--at <index>]
  divot theme show --json
  divot theme set <family> [--mode system|dark|light]

For anything else, use the generic key/value form:
  divot config get <key> [--json]
  divot config set <key> <value> [--dry-run] [--diff] [--json]
  divot config unset <key>
  divot config validate

Rules:
- Discover keys from `divot config schema --json`; never guess a key.
- Let the CLI write the file. Do not edit ~/.config/divot/config.json by hand.
- Use `--dry-run` or `--diff` when you want to show me an edit first.
- Exit codes: 0 ok, 1 invalid value or file, 2 usage error. A non-zero exit
  means the last good configuration is still in place — read the message and
  correct the value rather than retrying it.
- After an edit, confirm it with `divot config get <key>` or `divot status --json`.
```

## Read the contract first

`divot config schema --json` is generated from the same registry the loader, the Settings window, and the CLI write through, so it cannot describe a setting the app does not have. Each entry carries the dotted `key`, its `type`, the `default`, the allowed `values` or numeric `range`, and whether it is `writable`. Treat it as the source of truth.

`divot status --json` is the read-only diagnostic snapshot: the app version, whether a Divot instance is running, the Accessibility and Location permission readings, the detected workspace adapter, and the config path with its validity. It never prompts for a permission, launches the app, or writes a file.

## The focused helpers

Two edits come up more than any other, so they have named commands that read and write through the same configuration layer.

```bash
divot items list --json
divot items add date --side left --at 0
divot items remove appearance
divot items move workspaces --side right
divot theme show --json
divot theme set gruvbox --mode dark
```

`items` accepts only the eight placeable items: `workspaces`, `front-app`, `battery`, `network`, `volume`, `date`, `time`, and `appearance`. An unknown or legacy (`clock`) spelling, adding an item that is already placed, or an `--at` outside the destination group is refused. `add` appends to the right group unless `--side` says otherwise; `move` keeps the item's current side unless `--side` is given; and removing an item also clears its per-item options so the document stays valid.

`theme set` validates the family and the `--mode` through the same schema as `divot config set appearance.family` and `appearance.mode`, so the accepted names and the error text match the generic command. With `--mode` omitted the current mode is kept.

## What is implemented today

| Piece | Status |
| --- | --- |
| Version 2 config file, atomic store, and file watcher | Implemented in source |
| `divot config schema` / `get` / `set` / `unset` / `validate` / `show` | Implemented in source |
| `divot status` (plain and `--json`) | Implemented in source |
| `divot items list` / `add` / `remove` / `move` | Implemented in source |
| `divot theme show` / `set` | Implemented in source |
| Signed, notarized download and Homebrew cask | Planned — see the [roadmap](./roadmap) |

The commands document the app that is in this repository; they are not a promise of a hosted service. Nothing here asks an agent to grant a permission or to reach the network.
