import { describe, expect, test } from 'bun:test'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * Windowless unit tests (#0091). A `swift test` run must never put a Divot bar,
 * popover, or panel on the maintainer's screen, activate the app, or touch a
 * real system surface. Every window-visible call goes through the injected
 * `WindowPresenting` seam instead; this static guard covers every test file,
 * including ones that do not opt into the Swift `.windowless` trait.
 */

const testsRoot = fileURLToPath(new URL('../macos/Tests', import.meta.url))
const sourcesRoot = fileURLToPath(new URL('../macos/Sources', import.meta.url))

function swiftFiles(dir: string): string[] {
  const files: string[] = []
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry)
    if (statSync(full).isDirectory()) files.push(...swiftFiles(full))
    else if (entry.endsWith('.swift')) files.push(full)
  }
  return files
}

/** A leading dot keeps a protocol method definition (`func makeKeyAndOrderFront(`
 * in the recording presenter) from counting as a call on a real window. */
const FORBIDDEN: Array<{ label: string; pattern: RegExp }> = [
  { label: 'orders a window front', pattern: /\.(orderFront|orderFrontRegardless|makeKeyAndOrderFront)\(/ },
  { label: 'activates the app', pattern: /\bNSApp\.activate\(|NSApplication\.shared\.activate|activate\(ignoringOtherApps/ },
  { label: 'changes the activation policy', pattern: /\.setActivationPolicy\(/ },
  { label: 'posts a real notification', pattern: /\bUNUserNotificationCenter\b|\bNSUserNotification\b/ },
  { label: 'opens System Settings', pattern: /openSystemSettings/ },
]

describe('windowless swift tests', () => {
  test('no test orders a window front, activates the app, or touches a system surface', () => {
    const offenders: string[] = []
    for (const file of swiftFiles(testsRoot)) {
      const source = readFileSync(file, 'utf8')
      for (const { label, pattern } of FORBIDDEN) {
        if (pattern.test(source)) offenders.push(`${file}: ${label}`)
      }
    }
    expect(offenders).toEqual([])
  })

  test('production makes a Divot window visible only through the presenter seam', () => {
    const panels = readFileSync(join(sourcesRoot, 'DivotAppKit/BarPanels.swift'), 'utf8')
    const popover = readFileSync(join(sourcesRoot, 'DivotAppKit/BarPopover.swift'), 'utf8')
    const presenter = readFileSync(join(sourcesRoot, 'DivotAppKit/WindowPresenter.swift'), 'utf8')

    expect(presenter).toContain('protocol WindowPresenting')
    // The panels and the popover route their front-ordering through the seam.
    expect(panels).toContain('presenter.orderFrontRegardless(')
    expect(panels).not.toContain('.orderFrontRegardless()')
    expect(popover).toContain('presenter.makeKeyAndOrderFront(')
    expect(popover).not.toContain('panel.makeKeyAndOrderFront(')
  })
})
