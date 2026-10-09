# Widgets

A widget pairs a small native view with a provider that knows when its data changes. Rendering and collection are separate so a slow integration cannot stall the whole bar.

## Built-in items (planned)

| Identifier | Default side | Role | Update strategy |
| --- | --- | --- | --- |
| `workspaces` | left | Window-manager workspaces | Manager events or bounded refresh |
| `front-app` | left | Frontmost application | Workspace/application notifications |
| `battery` | right | Charge and power state | System power notifications |
| `clock` | right | Local time with weekday and date | Next minute boundary by default |
| `network` | right | Wi-Fi/network status | Network path notifications |
| `volume` | right | Output volume | Audio notifications |

Both sides are ordered item groups and every supported item can move between them. Workspace app icons and empty-state visibility are optional settings on `workspaces`. The preview's values are static samples.

## Failure behavior

A disabled provider removes its observers and cancels outstanding work. A failed provider gets an understandable unavailable state while the rest of the bar keeps working. Background results from an old configuration are ignored.

## Future script widgets

Scripts are a later milestone. The protocol should have output limits, deadlines, cancellation, and a documented data format. No script API is available yet; do not assume xbar or SketchyBar compatibility.

Scripts will be trusted local programs, not safely sandboxed by a timeout. The first release prioritizes native providers so a normal setup does not continually launch shell processes.
