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

/** The rows of a `[[table]]` array, each cut off before the next table header.
 * Array-of-tables headers must start a line, so a comment that merely mentions
 * one cannot be mistaken for a row. */
function tableRows(source: string, header: string): string[] {
  const escaped = header.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return source
    .split(new RegExp(`^[ \\t]*${escaped}[ \\t]*$`, 'm'))
    .slice(1)
    .map((row) => row.split(/\n[ \t]*\[/)[0]!)
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
  name?: string
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
    name: value(release, 'name'),
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
  if (config.name !== undefined && !config.name.trim()) {
    throw new Error('release.name must not be blank')
  }
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
  return tableRows(source, '[[distribution]]').map((row) => {
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

interface DeploymentRow {
  name: string
  service?: string
  branch: string
  provider?: string
  url?: string
  dashboardUrl?: string
  subdir?: string
}

/** Parse the `[[deployments]]` rows, mirroring RepoOS's required fields. */
function parseDeployments(source: string): DeploymentRow[] {
  return tableRows(source, '[[deployments]]').map((row) => {
    const name = value(row, 'name')
    if (!name) throw new Error('deployments.name is required')
    const branch = value(row, 'branch')
    if (!branch) throw new Error(`${name}: branch is required`)
    const url = value(row, 'url')
    if (url && !/^https?:\/\//i.test(url)) {
      throw new Error(`${name}: url must start with http(s)://`)
    }
    const dashboardUrl = value(row, 'dashboard_url')
    if (dashboardUrl && !/^https?:\/\//i.test(dashboardUrl)) {
      throw new Error(`${name}: dashboard_url must start with http(s)://`)
    }
    return {
      name,
      service: value(row, 'service'),
      branch,
      provider: value(row, 'provider'),
      url,
      dashboardUrl,
      subdir: value(row, 'subdir'),
    }
  })
}

const release = parseReleaseConfig(repoos)
const distributions = parseDistributions(repoos)
const deployments = parseDeployments(repoos)

describe('release configuration', () => {
  test('opts into git-tag releases from main read from package.json', () => {
    expect(release.enabled).toBe('true')
    expect(release.name).toBe('Publish Divot')
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

  test('declares the dev and prod Cloudflare Workers deployments', () => {
    expect(deployments).toHaveLength(2)

    const prod = deployments.find((row) => row.name === 'Site (prod)')
    expect(prod?.branch).toBe('prod')
    expect(prod?.provider).toBe('cloudflare-workers')
    expect(prod?.url).toBe('https://divotbar.app')
    expect(prod?.subdir).toBe('site')

    const dev = deployments.find((row) => row.name === 'Site (dev)')
    expect(dev?.branch).toBe('main')
    expect(dev?.provider).toBe('cloudflare-workers')
    expect(dev?.url).toBe('https://main-divot-site.njachowski.workers.dev')
    expect(dev?.subdir).toBe('site')
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

  test('rejects a blank release name', () => {
    expect(() => parseReleaseConfig(valid.replace('enabled = true', 'enabled = true\nname = ""'))).toThrow()
    expect(() =>
      parseReleaseConfig(valid.replace('enabled = true', 'enabled = true\nname = "Publish Divot"')),
    ).not.toThrow()
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

  test('rejects a deployment row without a name or branch', () => {
    const valid = '[[deployments]]\nname = "Site (dev)"\nbranch = "main"\n'
    expect(() => parseDeployments(valid.replace('name = "Site (dev)"\n', ''))).toThrow()
    expect(() => parseDeployments(valid.replace('branch = "main"\n', ''))).toThrow()
    expect(() => parseDeployments(valid)).not.toThrow()
  })

  test('rejects a deployment row with a non-http url or dashboard_url', () => {
    const valid = '[[deployments]]\nname = "Site (dev)"\nbranch = "main"\n'
    expect(() => parseDeployments(`${valid}url = "ftp://example.com"\n`)).toThrow()
    expect(() => parseDeployments(`${valid}dashboard_url = "not-a-url"\n`)).toThrow()
  })
})

describe('release version sources', () => {
  const SEMVER = /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/

  test('package.json carries a semver release version', () => {
    expect(String(packageJson.version)).toMatch(SEMVER)
  })

  test('while VERSION is a preview, package.json matches it', () => {
    // Once RepoOS cuts a real release it writes package.json only; VERSION
    // stays the local-preview number, so the two may then differ.
    if (!PREVIEW_VERSION.test(version)) return
    if (!PREVIEW_VERSION.test(String(packageJson.version))) return
    expect(packageJson.version).toBe(version)
  })
})
