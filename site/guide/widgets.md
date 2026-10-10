# Widgets

A widget pairs a small native view with a provider that knows when its data changes. Rendering and collection are separate so a slow integration cannot stall the whole bar.

::: warning Pre-alpha status
The native providers below are implemented and unit-tested in the Swift package, but there is no signed app yet and they are not physically validated on hardware. On this website the bar preview uses static sample values; the running app (built from source) reads live local values.
:::

## Built-in items

| Identifier | Default side | Role | Update strategy |
| --- | --- | --- | --- |
| `workspaces` | left | Window-manager workspaces | Manager events or bounded refresh (AeroSpace and yabai adapters delivered; not physically validated) |
| `front-app` | left | Frontmost application | Workspace/application notifications |
| `battery` | right | Charge and power state | System power notifications |
| `clock` | right | Local time with weekday and date | Next minute boundary by default |
| `network` | right | Wi-Fi/network status | Network path notifications |
| `volume` | right | Output volume | Audio notifications |

Both sides are ordered item groups and every supported item can move between them. The native app fills this default bar from built-in providers — no setup questionnaire and no shell polling. Workspace app icons and empty-state visibility are optional settings on `workspaces`.

## Failure and unavailable states

A disabled provider removes its observers and cancels outstanding work. A failed provider gets an understandable unavailable state while the rest of the bar keeps working; a late background result from an old configuration or a disabled provider is ignored. A desktop Mac shows a settled no-battery state rather than an error.

## Permissions

The clock, battery, network, volume, and frontmost-app items need no special permission. Network status deliberately reads no SSID or other location-gated detail, so it never triggers a location prompt. Accessibility is only relevant to detecting the native menu bar on notched displays, not to these widgets.

## Click behavior

Divot does not mirror the system's menu extras. Each item has one explicit action: the frontmost-app item activates that app, and the battery, network, volume, and clock items open the matching System Settings pane. The exact pane links still need validation on the target OS, and a later milestone may replace the volume/network links with a native control popover.

## Future script widgets

Scripts are a later milestone. The protocol should have output limits, deadlines, cancellation, and a documented data format. No script API is available yet; do not assume xbar or SketchyBar compatibility.

Scripts will be trusted local programs, not safely sandboxed by a timeout. The first release prioritizes native providers so a normal setup does not continually launch shell processes.
