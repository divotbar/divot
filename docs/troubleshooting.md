# Troubleshooting and Known Limitations

This document lists known limitations and technical constraints that affect Divot's behavior. Limitations are organized by feature area, with evidence links and workarounds where applicable.

## Notification banner overlap when the menu bar is auto-hidden

**Limitation:** When the native macOS menu bar is set to auto-hide and a notification banner appears, the banner's title row may be partly covered by the Divot bar.

**Root cause:** See [evidence/0075-notification-banner-overlap.md](evidence/0075-notification-banner-overlap.md) for the full technical analysis. Summary:

- Divot is positioned at y=0 (screen top) when the native menu bar is hidden.
- macOS positions notification banners at y=33, matching the menu bar height on notched displays.
- Notification banners use a window level above the Divot bar, so they draw on top but in the same visual area.
- No public macOS API allows Divot to reorder below banners while staying above normal app windows and respecting the menu-bar-on-top constraint.

**Workarounds:**

1. **Disable menu bar auto-hide:** In System Settings → Dock & Menu Bar, turn off auto-hide.
   Banners reposition below the visible menu bar. No overlap occurs.

2. **Use cursor-reveal (Settings → Move below the menu bar when it appears):**
   Pointer entry slides the bar below a revealed menu bar. Banners do not follow this animation,
   so overlap can still occur if a banner arrives while the bar is at the top edge.

3. **Accept the limitation:** A few points of banner title coverage is the trade-off for
   Divot occupying the top edge when the menu bar is hidden.

**Will this be fixed?** Not without compromising the top-edge design (task #0021)
or adding an optional inset when the menu bar is hidden (not currently planned).
A future task could explore this trade-off if the limitation becomes blocking.

## Other constraints

(To be filled in as physical validation identifies additional limitations.)
