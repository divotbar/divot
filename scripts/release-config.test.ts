import { describe, expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'

/**
 * Guards the RepoOS release surface (#0067) and the version it reads. The
 * release manifest and the local-preview version are two files by necessity
 * (RepoOS needs JSON; the packaging script reads the plain-text VERSION), so
 * this test is what keeps a one-sided version bump from landing silently.
 *
 * `parseReleaseConfig` / `parseDistributions` mirror the rules RepoOS applies
 * when it loads repoos.toml: a bad shape throws here (and is dropped with a
 * warning by RepoOS) rather than silently disabling the Releases page.
 */

const repoos = readFileSync(new URL('../repoos.toml', import.meta.url), 'utf8')
const version = readFileSync(new URL('../VERSION', import.meta.url), 'utf8').trim()
const packageJson = JSON.parse(
  readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
) as { version?: unknown }

const PREVIEW_VERSION = /^\d+\.\d+\.\d+-preview\.\d+$/
const OWNER_REPO = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
const DISTRIBUTION_KINDS = ['npm', 'homebrew', 'github-release', 'custom']

/** The body of a `[section]`, up to the next table/array header. */
function section(source: string, header: string): string {
  const lines = source.split('\n')
  const start = lines.findIndex((line) => line.trim() === header)
  if (start < 0) throw new Error(`repoos.toml: missing ${header}`)
  const body: string[] = []
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^\s*\[/.test(lines[i]!)) break
    body.push(lines[i]!)
  }
  return body.join('\n')
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

interface ReleaseConfig {
  enabled?: string
  provider?: string
  branch?: string
  versionFile?: string
  tagPrefix?: string
  remote?: string
  repository?: string
  workflow?: string
}

/** Parse the `[release]` block, rejecting a prohibited shape. */
function parseReleaseConfig(source: string): ReleaseConfig {
  const release = section(source, '[release]')
  const config: ReleaseConfig = {
    enabled: value(release, 'enabled'),
    provider: value(release, 'provider'),
    branch: value(release, 'branch'),
    versionFile: value(release, 'versionFile'),
    tagPrefix: value(release, 'tagPrefix'),
    remote: value(release, 'remote'),
    repository: value(release, 'repository'),
    workflow: value(release, 'workflow'),
  }
  if (config.enabled !== 'true') throw new Error('release.enabled must be true')
  if (config.provider !== 'git-tag') throw new Error('release.provider must be git-tag')
  if (!config.branch) throw new Error('release.branch is required')
  if (!config.versionFile?.endsWith('.json')) {
    throw new Error('release.versionFile must name a JSON manifest')
  }
  if (config.repository && !OWNER_REPO.test(config.repository)) {
    throw new Error('release.repository must be owner/repo')
  }
  return config
}

interface DistributionRow {
  name: string
  kind?: string
  url?: string
  repository?: string
  package?: string
  versionUrl?: string
  versionRegex?: string
}

/** Parse the `[[distribution]]` rows, rejecting prohibited shapes. */
function parseDistributions(source: string): DistributionRow[] {
  return source
    .split('[[distribution]]')
    .slice(1)
    .map((row) => {
      const name = value(row, 'name')
      if (!name) throw new Error('distribution.name is required')
      const kind = value(row, 'kind')
      if (kind && !DISTRIBUTION_KINDS.includes(kind)) {
        throw new Error(`${name}: unknown distribution kind "${kind}"`)
      }
      const url = value(row, 'url')
      if (url && !/^https?:\/\//i.test(url)) {
        throw new Error(`${name}: url must start with http(s)://`)
      }
      const repository = value(row, 'repository')
      if (kind === 'github-release' && (!repository || !OWNER_REPO.test(repository))) {
        throw new Error(`${name}: github-release repository must be owner/repo`)
      }
      const versionUrl = value(row, 'versionUrl')
      if (versionUrl && !/^https?:\/\//i.test(versionUrl)) {
        throw new Error(`${name}: versionUrl must start with http(s)://`)
      }
      const versionRegex = value(row, 'versionRegex')
      if (kind === 'homebrew' && !versionRegex) {
        throw new Error(`${name}: homebrew versionRegex is required`)
      }
      if (versionRegex) {
        try {
          new RegExp(versionRegex)
        } catch {
          throw new Error(`${name}: versionRegex is not a valid regex`)
        }
      }
      return {
        name,
        kind,
        url,
        repository,
        package: value(row, 'package'),
        versionUrl,
        versionRegex,
      }
    })
}

const release = parseReleaseConfig(repoos)
const distributions = parseDistributions(repoos)

describe('release configuration', () => {
  test('opts into git-tag releases from main read from package.json', () => {
    expect(release.enabled).toBe('true')
    expect(release.provider).toBe('git-tag')
    expect(release.branch).toBe('main')
    expect(release.tagPrefix).toBe('v')
    expect(release.remote).toBe('origin')
    expect(release.repository).toBe('divotbar/divot')
    expect(release.workflow).toBe('.github/workflows/release.yml')
    expect(release.versionFile).toBe('package.json')
  })

  test('declares the GitHub Releases and Homebrew install channels', () => {
    expect(distributions).toHaveLength(2)
    const github = distributions.find((row) => row.name === 'GitHub Releases')
    expect(github?.kind).toBe('github-release')
    expect(github?.repository).toBe('divotbar/divot')
    expect(github?.url).toBe('https://github.com/divotbar/divot/releases/tag/{tag}')

    const homebrew = distributions.find((row) => row.name === 'Homebrew')
    expect(homebrew?.kind).toBe('homebrew')
    expect(homebrew?.package).toBe('divotbar/tap/divot')
    expect(homebrew?.url).toBe(
      'https://github.com/divotbar/homebrew-tap/blob/main/Casks/divot.rb',
    )
    expect(homebrew?.versionUrl).toBe(
      'https://raw.githubusercontent.com/divotbar/homebrew-tap/main/Casks/divot.rb',
    )
    expect(homebrew?.versionRegex).toBe('version\\s+"([^"]+)"')
  })

  test('declares no deployment rows before Cloudflare values exist', () => {
    expect(/^\[\[deployments\]\]/m.test(repoos)).toBe(false)
  })
})

describe('release configuration rejection', () => {
  const valid =
    '[release]\nenabled = true\nprovider = "git-tag"\nbranch = "main"\nversionFile = "package.json"\n'

  test('rejects a disabled or non-git-tag release block', () => {
    expect(() => parseReleaseConfig(valid.replace('enabled = true', 'enabled = false'))).toThrow()
    expect(() =>
      parseReleaseConfig(valid.replace('provider = "git-tag"', 'provider = "github-releases"')),
    ).toThrow()
  })

  test('rejects a versionFile that is not a JSON manifest', () => {
    expect(() =>
      parseReleaseConfig(valid.replace('versionFile = "package.json"', 'versionFile = "VERSION"')),
    ).toThrow()
  })

  test('rejects a distribution row with a non-http url', () => {
    expect(() =>
      parseDistributions(
        '[[distribution]]\nname = "GitHub Releases"\nkind = "github-release"\nrepository = "divotbar/divot"\nurl = "ftp://example.com/x"\n',
      ),
    ).toThrow()
  })

  test('rejects an unknown distribution kind', () => {
    expect(() =>
      parseDistributions('[[distribution]]\nname = "Snap"\nkind = "snap"\nurl = "https://example.com"\n'),
    ).toThrow()
  })

  test('rejects a github-release row with a malformed repository', () => {
    expect(() =>
      parseDistributions(
        '[[distribution]]\nname = "GitHub Releases"\nkind = "github-release"\nrepository = "divotbar"\nurl = "https://example.com"\n',
      ),
    ).toThrow()
  })

  test('rejects a homebrew row with a missing or non-compiling versionRegex', () => {
    const homebrew =
      '[[distribution]]\nname = "Homebrew"\nkind = "homebrew"\npackage = "divotbar/tap/divot"\nurl = "https://example.com"\nversionUrl = "https://example.com/divot.rb"\n'
    expect(() => parseDistributions(homebrew)).toThrow()
    expect(() => parseDistributions(`${homebrew}versionRegex = "("\n`)).toThrow()
  })
})

describe('release version sources', () => {
  test('the package.json release version matches the VERSION preview', () => {
    expect(packageJson.version).toBe(version)
    expect(packageJson.version).toMatch(PREVIEW_VERSION)
  })
})
