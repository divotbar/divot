import { describe, expect, test } from 'bun:test'
import { readFileSync, statSync } from 'node:fs'

interface CheckStep {
  name: string
  command: string
}

/** Parse the `[[check.steps]]` blocks out of a repoos.toml document. */
function checkSteps(source: string): CheckStep[] {
  return source
    .split(/\[\[check\.steps\]\]/)
    .slice(1)
    .map((block) => ({
      name: /^\s*name\s*=\s*"([^"]+)"/m.exec(block)?.[1] ?? '',
      command: /^\s*command\s*=\s*"([^"]*)"/m.exec(block)?.[1] ?? '',
    }))
}

const SMOKE_COMMAND = 'scripts/smoke-app-bundle.sh'

/**
 * The `repoos check` gate that packages and launches the local preview. Throws
 * when the step is missing or weakened so a bad repoos.toml is rejected rather
 * than silently skipping the launch smoke.
 */
function requirePreviewGate(source: string): CheckStep {
  const step = checkSteps(source).find((s) => s.name === 'native-app-bundle')
  if (!step) {
    throw new Error('repoos.toml: the native-app-bundle preview gate is missing')
  }
  if (step.command.trim() !== SMOKE_COMMAND) {
    throw new Error(`repoos.toml: native-app-bundle does not run the smoke script: ${step.command}`)
  }
  return step
}

/** Recipe names declared at column 0 in a justfile. */
function justRecipes(source: string): string[] {
  return [...source.matchAll(/^([a-zA-Z][\w-]*)(?:\s+[^\s:]+)*\s*:(?!=)/gm)].map((m) => m[1]!)
}

const justfile = readFileSync(new URL('../justfile', import.meta.url), 'utf8')
const repoos = readFileSync(new URL('../repoos.toml', import.meta.url), 'utf8')
const version = readFileSync(new URL('../VERSION', import.meta.url), 'utf8').trim()
const packageScript = readFileSync(new URL('./package-app.sh', import.meta.url), 'utf8')
const smokeScript = readFileSync(new URL('./smoke-app-bundle.sh', import.meta.url), 'utf8')

describe('local preview gate', () => {
  test('justfile documents the app build and run recipes', () => {
    const recipes = justRecipes(justfile)
    for (const recipe of ['app-package', 'app-smoke', 'app-run']) {
      expect(recipes).toContain(recipe)
    }
    // The usable preview must be a Release build, not a debug one.
    expect(packageScript).toContain('CONFIGURATION="release"')
  })

  test('repoos.toml declares the preview package-and-launch gate', () => {
    const step = requirePreviewGate(repoos)
    expect(step.command).toBe(SMOKE_COMMAND)
  })

  test('rejects a repoos.toml that drops the preview gate', () => {
    const without = `
      [[check.steps]]
      name = "native-app"
      command = "swift build --package-path macos --product divot"
    `
    expect(() => requirePreviewGate(without)).toThrow('native-app-bundle')
  })

  test('rejects a preview gate that no longer launches the bundle', () => {
    const weakened = `
      [[check.steps]]
      name = "native-app-bundle"
      command = "scripts/package-app.sh"
    `
    expect(() => requirePreviewGate(weakened)).toThrow('does not run the smoke script')
  })

  test('VERSION is an honest preview version', () => {
    expect(version).toMatch(/^\d+\.\d+\.\d+-preview\.\d+$/)
  })

  test('the packaging scripts are executable', () => {
    for (const url of ['./package-app.sh', './smoke-app-bundle.sh']) {
      const mode = statSync(new URL(url, import.meta.url)).mode
      expect(mode & 0o111).toBeGreaterThan(0)
    }
  })

  test('packaging signs ad-hoc and never weakens security', () => {
    // Ad-hoc signing is the anonymous identity "-", never a guessed name.
    expect(packageScript).toMatch(/codesign --force --sign -(\s|$)/m)
    expect(packageScript).toContain('not Developer ID signed, not notarized')
    // Scan the runnable script only; the header comment names what it refuses.
    const code = packageScript
      .split('\n')
      .filter((line) => !/^\s*#/.test(line))
      .join('\n')
      .toLowerCase()
    for (const forbidden of ['sudo ', 'xattr', 'spctl', 'quarantine', 'gatekeeper', 'gh ', 'curl ']) {
      expect(code).not.toContain(forbidden)
    }
    // The local bundle identifier is a clear placeholder, not a public identity.
    expect(packageScript).toContain('local.divot.preview')
  })

  test('the smoke script actually launches the packaged executable', () => {
    expect(smokeScript).toContain('Contents/MacOS/divot"')
    expect(smokeScript).toContain('--help')
    expect(smokeScript).toContain('--report')
    expect(smokeScript).toContain('--widgets')
    expect(smokeScript).toContain('status --json')
    expect(smokeScript).toContain('layout.left=workspaces,front-app')
    expect(smokeScript).toContain('layout.right=battery,time,network,volume')
    // It must verify the signature and the archive checksum.
    expect(smokeScript).toContain('codesign --verify --deep --strict')
    expect(smokeScript).toContain('sha256')
  })

  test('the guide labels the preview as local, not a public release', () => {
    const guide = readFileSync(new URL('../docs/local-preview.md', import.meta.url), 'utf8')
    expect(guide).toContain('ad-hoc')
    expect(guide.toLowerCase()).toContain('not notarized')
    expect(guide).toContain('#0008')
    // The guide must not tell people to strip quarantine.
    expect(guide.toLowerCase()).not.toContain('xattr')
  })
})
