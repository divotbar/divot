import { describe, expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'

/**
 * Guards the RepoOS release surface (#0067) and the version it reads. The
 * release manifest and the local-preview version are two files by necessity
 * (RepoOS needs JSON; the packaging script reads the plain-text VERSION), so
 * this test is what keeps a one-sided version bump from landing silently.
 */

const repoos = readFileSync(new URL('../repoos.toml', import.meta.url), 'utf8')
const version = readFileSync(new URL('../VERSION', import.meta.url), 'utf8').trim()
const packageJson = JSON.parse(
  readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
) as { version?: unknown }

const PREVIEW_VERSION = /^\d+\.\d+\.\d+-preview\.\d+$/

/** The body of a `[section]`, up to the next table/array header. */
function section(source: string, header: string): string {
  const start = source.indexOf(`\n${header}\n`)
  if (start < 0) throw new Error(`repoos.toml: missing ${header}`)
  const rest = source.slice(start + header.length + 2)
  const end = rest.search(/^\[/m)
  return end < 0 ? rest : rest.slice(0, end)
}

/** A `key = value` scalar (quoted or boolean) from a TOML fragment. */
function value(source: string, key: string): string | undefined {
  const match = new RegExp(`^\\s*${key}\\s*=\\s*(.+?)\\s*$`, 'm').exec(source)
  if (!match) return undefined
  const raw = match[1]!
  if (raw === 'true' || raw === 'false') return raw
  const quoted = /^"(.*)"$/.exec(raw) ?? /^'(.*)'$/.exec(raw)
  return quoted ? quoted[1] : raw
}

const release = section(repoos, '[release]')
const distributions = repoos.split('[[distribution]]').slice(1)

describe('release configuration', () => {
  test('opts into git-tag releases from main read from package.json', () => {
    expect(value(release, 'enabled')).toBe('true')
    expect(value(release, 'provider')).toBe('git-tag')
    expect(value(release, 'branch')).toBe('main')
    expect(value(release, 'tagPrefix')).toBe('v')
    expect(value(release, 'remote')).toBe('origin')
    expect(value(release, 'repository')).toBe('divotbar/divot')
    expect(value(release, 'workflow')).toBe('.github/workflows/release.yml')
    expect(value(release, 'versionFile')).toBe('package.json')
  })

  test('declares the GitHub Releases and Homebrew install channels', () => {
    expect(distributions).toHaveLength(2)
    const github = distributions.find((row) => /name\s*=\s*"GitHub Releases"/.test(row))
    expect(github).toBeDefined()
    expect(value(github ?? '', 'kind')).toBe('github-release')
    expect(value(github ?? '', 'repository')).toBe('divotbar/divot')
    expect(value(github ?? '', 'url')).toBe(
      'https://github.com/divotbar/divot/releases/tag/{tag}',
    )

    const homebrew = distributions.find((row) => /name\s*=\s*"Homebrew"/.test(row))
    expect(homebrew).toBeDefined()
    expect(value(homebrew ?? '', 'kind')).toBe('homebrew')
    expect(value(homebrew ?? '', 'package')).toBe('divotbar/tap/divot')
    expect(value(homebrew ?? '', 'url')).toBe(
      'https://github.com/divotbar/homebrew-tap/blob/main/Casks/divot.rb',
    )
    expect(value(homebrew ?? '', 'versionUrl')).toBe(
      'https://raw.githubusercontent.com/divotbar/homebrew-tap/main/Casks/divot.rb',
    )
    expect(value(homebrew ?? '', 'versionRegex')).toBe('version\\s+"([^"]+)"')
  })

  test('declares no deployment rows before Cloudflare values exist', () => {
    expect(/^\[\[deployments\]\]/m.test(repoos)).toBe(false)
  })
})

describe('release version sources', () => {
  test('the package.json release version matches the VERSION preview', () => {
    expect(packageJson.version).toBe(version)
    expect(packageJson.version).toMatch(PREVIEW_VERSION)
  })
})
