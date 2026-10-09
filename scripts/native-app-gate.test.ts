import { describe, expect, test } from 'bun:test'
import { spawnSync } from 'node:child_process'
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

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

const macosPackage = fileURLToPath(new URL('../macos', import.meta.url))

/**
 * Run the exact gate command against a package path, so the negative test
 * exercises the same `swift build ... --product divot` invocation that
 * `repoos check` runs, not a re-implementation of it.
 */
function nativeAppBuild(packagePath: string) {
  const argv = NATIVE_APP_COMMAND.split(/\s+/)
  const flag = argv.indexOf('--package-path')
  if (flag === -1) {
    throw new Error(`native-app gate command has no --package-path: ${NATIVE_APP_COMMAND}`)
  }
  argv[flag + 1] = packagePath
  const [bin, ...args] = argv
  return spawnSync(bin, args, { encoding: 'utf8' })
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

  test(
    'the app build command rejects a broken DivotApp input without touching the project',
    () => {
      const fixture = mkdtempSync(join(tmpdir(), 'divot-native-app-gate-'))
      try {
        // An isolated copy of the real package, minus build artifacts. Nothing
        // here writes into the working project.
        cpSync(macosPackage, fixture, {
          recursive: true,
          filter: (source) => !source.split('/').includes('.build'),
        })

        // Positive control: the fixture is a faithful, buildable package, so a
        // later failure can only come from the input we break.
        const healthy = nativeAppBuild(fixture)
        expect(healthy.status).toBe(0)

        const fixtureMain = join(fixture, 'Sources', 'DivotApp', 'main.swift')
        const source = readFileSync(fixtureMain, 'utf8')
        writeFileSync(fixtureMain, `${source}\nlet divotGateNegativeFixture: Int = "not an Int"\n`)

        // The exact gate command now fails on the broken app input.
        const broken = nativeAppBuild(fixture)
        expect(broken.status).not.toBe(0)
        const output = `${broken.stdout}\n${broken.stderr}`
        expect(output).toContain('DivotApp')
        expect(output).toContain('error:')

        // The working project is untouched: only the temp fixture was broken.
        const projectMain = join(macosPackage, 'Sources', 'DivotApp', 'main.swift')
        expect(readFileSync(projectMain, 'utf8')).toBe(source)
      } finally {
        rmSync(fixture, { recursive: true, force: true })
      }
    },
    180_000,
  )
})
