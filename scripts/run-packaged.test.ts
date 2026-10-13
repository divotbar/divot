import { describe, expect, test } from 'bun:test'
import { spawn, spawnSync, type ChildProcess } from 'node:child_process'
import { readFileSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * The packaged Dev target (#0094). `scripts/run-packaged.sh` rebuilds and runs
 * the real dist/Divot.app; `scripts/run-dev.sh` runs the bare dev binary and
 * stops the packaged bar first so two bars never stack. These tests exercise the
 * script's pure parts — argument handling, the exact-path PID discovery, the
 * dry-run plan — and assert the committed repoos.toml declares both targets.
 */

const packagedScript = fileURLToPath(new URL('./run-packaged.sh', import.meta.url))
const devScript = fileURLToPath(new URL('./run-dev.sh', import.meta.url))
const packagedSource = readFileSync(new URL('./run-packaged.sh', import.meta.url), 'utf8')
const devSource = readFileSync(new URL('./run-dev.sh', import.meta.url), 'utf8')
const repoos = readFileSync(new URL('../repoos.toml', import.meta.url), 'utf8')

interface DevTarget {
  name: string
  kind: string
  command: string
  label: string
}

/** Parse the `[[dev.targets]]` blocks out of a repoos.toml document. */
function devTargets(source: string): DevTarget[] {
  return source
    .split(/\[\[dev\.targets\]\]/)
    .slice(1)
    .map((block) => ({
      name: /^\s*name\s*=\s*"([^"]+)"/m.exec(block)?.[1] ?? '',
      kind: /^\s*kind\s*=\s*"([^"]+)"/m.exec(block)?.[1] ?? '',
      command: /^\s*command\s*=\s*"([^"]*)"/m.exec(block)?.[1] ?? '',
      label: /^\s*label\s*=\s*"([^"]*)"/m.exec(block)?.[1] ?? '',
    }))
}

function runPackaged(...args: string[]) {
  return spawnSync(packagedScript, args, { encoding: 'utf8' })
}

/** The PIDs the script would match for an exact executable path. */
function printPids(path: string): number[] {
  const result = runPackaged('--print-pids', path)
  expect(result.status).toBe(0)
  return result.stdout
    .split('\n')
    .map((line) => Number.parseInt(line.trim(), 10))
    .filter((pid) => Number.isInteger(pid) && pid > 0)
}

/**
 * Start a harmless process whose argv[0] is a chosen string, so PID discovery
 * can be tested against a real process without launching any Divot UI. `exec -a`
 * sets argv[0]; `sleep` keeps it alive until the test kills it by PID.
 */
function decoy(argv0: string): ChildProcess {
  if (argv0.includes("'")) throw new Error('decoy argv0 must not contain a single quote')
  return spawn('bash', ['-c', `exec -a '${argv0}' sleep 30`], { stdio: 'ignore' })
}

/** Poll until the decoy appears in `ps` (argv[0] is visible almost immediately). */
async function waitForPid(path: string, pid: number): Promise<void> {
  const deadline = Date.now() + 3000
  while (Date.now() < deadline) {
    if (printPids(path).includes(pid)) return
    await Bun.sleep(50)
  }
  throw new Error(`decoy pid ${pid} did not appear for ${path}`)
}

function killQuietly(child: ChildProcess | undefined) {
  if (child && child.pid && child.exitCode === null) {
    try {
      child.kill('SIGKILL')
    } catch {
      /* already gone */
    }
  }
}

describe('run-packaged.sh argument handling', () => {
  test('--help prints usage and exits 0', () => {
    const result = runPackaged('--help')
    expect(result.status).toBe(0)
    expect(result.stdout).toContain('Usage: scripts/run-packaged.sh')
  })

  test('an unknown argument exits 2', () => {
    const result = runPackaged('--not-a-flag')
    expect(result.status).toBe(2)
    expect(result.stderr).toContain('unknown argument')
  })

  test('an unsupported --configuration exits 2', () => {
    const result = runPackaged('--configuration', 'fast')
    expect(result.status).toBe(2)
    expect(result.stderr).toContain('debug or release')
  })
})

describe('run-packaged.sh dry run', () => {
  test('prints the build, launch and stop plan without changing anything', () => {
    const result = runPackaged('--dry-run')
    expect(result.status).toBe(0)
    expect(result.stdout).toContain('dry run (nothing is changed)')
    expect(result.stdout).toContain('scripts/package-app.sh --configuration release --no-archive')
    expect(result.stdout).toContain('open ')
    expect(result.stdout).toContain('running commit')
    expect(result.stdout).toContain('on SIGTERM')
  })

  test('honours --configuration debug', () => {
    const result = runPackaged('--dry-run', '--configuration', 'debug')
    expect(result.status).toBe(0)
    expect(result.stdout).toContain('scripts/package-app.sh --configuration debug --no-archive')
  })
})

describe('run-packaged.sh PID discovery', () => {
  test('matches a process by its exact executable path, never by name', async () => {
    const exact = join(tmpdir(), `divot-run-packaged-exact-${process.pid}`)
    const other = join(tmpdir(), `divot-run-packaged-other-${process.pid}`)
    const byName = decoy('divot')
    const byPath = decoy(exact)
    try {
      await waitForPid(exact, byPath.pid!)
      // Exact path matches, and only that PID.
      expect(printPids(exact)).toContain(byPath.pid!)
      // A different path matches nothing — no substring or name matching.
      expect(printPids(other)).not.toContain(byPath.pid!)
      // A bare `divot` process is never matched by a full path.
      expect(printPids(exact)).not.toContain(byName.pid!)
    } finally {
      killQuietly(byName)
      killQuietly(byPath)
    }
  })
})

describe('run-packaged.sh safety', () => {
  test('never kills by name or pattern', () => {
    const code = packagedSource
      .split('\n')
      .filter((line) => !/^\s*#/.test(line))
      .join('\n')
    for (const forbidden of ['pkill', 'killall', 'pgrep', 'killall5']) {
      expect(code).not.toContain(forbidden)
    }
    // It stops by PID and matches the exact executable path.
    expect(packagedSource).toContain('kill -TERM "$pid"')
    expect(packagedSource).toContain('kill -KILL "$pid"')
  })

  test('launches with open and stops both bar targets', () => {
    expect(packagedSource).toContain('open "$APP_DIR"')
    expect(packagedSource).toContain('macos/.build/debug/divot')
    expect(packagedSource).toContain('macos/.build/release/divot')
  })
})

describe('run-dev.sh', () => {
  test('is executable and supports --dry-run', () => {
    expect(statSync(devScript).mode & 0o111).toBeGreaterThan(0)
    const result = spawnSync(devScript, ['--dry-run'], { encoding: 'utf8' })
    expect(result.status).toBe(0)
    expect(result.stdout).toContain('swift run --package-path macos divot')
  })

  test('stops the packaged bar before running the dev binary', () => {
    expect(devSource).toContain('run-packaged.sh" --stop-only')
    expect(devSource).toContain('exec swift run --package-path macos divot')
    // It must not stop processes by name or pattern either.
    expect(devSource).not.toContain('pkill')
    expect(devSource).not.toContain('killall')
  })
})

describe('repoos.toml dev targets', () => {
  test('declares the packaged target next to the dev-binary target', () => {
    const targets = devTargets(repoos)
    const dev = targets.find((t) => t.name === 'divot')
    const packaged = targets.find((t) => t.name === 'divot-packaged')
    expect(dev).toBeDefined()
    expect(packaged).toBeDefined()
    expect(dev!.kind).toBe('process')
    expect(packaged!.kind).toBe('process')
    expect(dev!.command).toBe('scripts/run-dev.sh')
    expect(packaged!.command).toBe('scripts/run-packaged.sh')
    expect(packaged!.label).toBe('Divot bar (packaged)')
  })
})

describe('docs cover the two targets and their permissions', () => {
  test('docs/local-preview.md explains the packaged-vs-dev difference', () => {
    const guide = readFileSync(new URL('../docs/local-preview.md', import.meta.url), 'utf8')
    expect(guide).toContain('Divot bar (packaged)')
    expect(guide).toContain('run-packaged.sh')
    expect(guide).toContain('Location')
    expect(guide.toLowerCase()).toContain('ad-hoc')
  })

  test('the site troubleshooting and getting-started pages cover permissions', () => {
    const troubleshooting = readFileSync(new URL('../site/guide/troubleshooting.md', import.meta.url), 'utf8')
    const gettingStarted = readFileSync(new URL('../site/guide/getting-started.md', import.meta.url), 'utf8')
    for (const page of [troubleshooting, gettingStarted]) {
      expect(page).toContain('packaged')
      expect(page).toContain('Location')
    }
    expect(troubleshooting).toContain('Accessibility')
  })
})
