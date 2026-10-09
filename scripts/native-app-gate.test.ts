import { describe, expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'

interface CheckStep {
  name: string
  command: string
}

/**
 * Parse the `[[check.steps]]` blocks out of a repoos.toml document. Only the
 * fields this guard needs are read; anything else is ignored.
 */
function checkSteps(source: string): CheckStep[] {
  return source
    .split(/\[\[check\.steps\]\]/)
    .slice(1)
    .map((block) => ({
      name: /^\s*name\s*=\s*"([^"]+)"/m.exec(block)?.[1] ?? '',
      command: /^\s*command\s*=\s*"([^"]*)"/m.exec(block)?.[1] ?? '',
    }))
}

const NATIVE_APP_COMMAND = 'swift build --package-path macos --product divot'

/**
 * The `repoos check` gate that proves the executable app shell still builds.
 * Returns the step, or throws when the gate is missing or weakened so a bad
 * repoos.toml is rejected instead of silently passing review.
 */
function requireNativeAppGate(source: string): CheckStep {
  const step = checkSteps(source).find((s) => s.name === 'native-app')
  if (!step) {
    throw new Error('repoos.toml: the native-app app build gate is missing')
  }
  if (step.command.trim() !== NATIVE_APP_COMMAND) {
    throw new Error(`repoos.toml: native-app gate does not build the app product: ${step.command}`)
  }
  return step
}

describe('native-app build gate', () => {
  test('repoos.toml declares the executable app build gate', () => {
    const toml = readFileSync(new URL('../repoos.toml', import.meta.url), 'utf8')
    const step = requireNativeAppGate(toml)
    expect(step.command).toBe(NATIVE_APP_COMMAND)
  })

  test('rejects a repoos.toml that drops the native-app gate', () => {
    const without = `
      [[check.steps]]
      name = "site"
      command = "bun run check"

      [[check.steps]]
      name = "native-core"
      command = "swift test --package-path macos"
    `
    expect(() => requireNativeAppGate(without)).toThrow('native-app')
  })

  test('rejects a native-app gate that no longer builds the app product', () => {
    const weakened = `
      [[check.steps]]
      name = "native-app"
      command = "swift build --package-path macos"
    `
    expect(() => requireNativeAppGate(weakened)).toThrow('does not build the app product')
  })
})
