import { spawnSync } from 'node:child_process'

/**
 * Docs/site drift guard (task #0065). The native configuration is a public
 * contract: whenever its sources change, the engineering contract and the
 * public reference must change in the same branch. This is a coarse, best
 * effort net — the AGENTS.md rule and the reviewer still cover behaviour that
 * a file-path diff cannot see.
 */

/** Native configuration sources whose keys the reference documents. */
export const CONFIG_SOURCE_PREFIX = 'macos/Sources/DivotCore/Configuration/'

/** Docs that must change when the configuration contract changes. */
export const CONFIG_DOCS = ['docs/configuration.md', 'site/reference/configuration.md'] as const

export interface DriftReport {
  /** Changed native configuration sources. */
  sources: string[]
  /** Required docs that did not change. */
  missing: string[]
}

export function findDrift(changedFiles: string[]): DriftReport {
  const sources = changedFiles.filter((file) => file.startsWith(CONFIG_SOURCE_PREFIX))
  if (sources.length === 0) return { sources, missing: [] }
  const missing = CONFIG_DOCS.filter((doc) => !changedFiles.includes(doc))
  return { sources, missing }
}

function git(args: string[]): string | undefined {
  const result = spawnSync('git', args, { encoding: 'utf8' })
  if (result.status !== 0) return undefined
  return result.stdout.trim()
}

/** The commit the branch grew from, so only this branch's edits are inspected. */
function resolveBaseRef(): string | undefined {
  const explicit = process.env.DOCS_DRIFT_BASE?.trim()
  if (explicit) return explicit
  for (const candidate of ['main', 'origin/main']) {
    if (git(['rev-parse', '--verify', '--quiet', candidate]) !== undefined) return candidate
  }
  return undefined
}

function main(): void {
  const base = resolveBaseRef()
  if (!base) {
    console.log('docs-drift: no base ref (set DOCS_DRIFT_BASE) — skipping')
    return
  }
  const mergeBase = git(['merge-base', base, 'HEAD'])
  const output = mergeBase === undefined ? undefined : git(['diff', '--name-only', mergeBase])
  if (output === undefined) {
    console.log(`docs-drift: cannot diff against ${base} — skipping`)
    return
  }
  const changed = output
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
  const { sources, missing } = findDrift(changed)
  if (sources.length === 0) {
    console.log('docs-drift: no configuration-source changes')
    return
  }
  if (missing.length === 0) {
    console.log('docs-drift: configuration docs are in sync')
    return
  }
  if (process.env.DOCS_DRIFT_ALLOW === '1') {
    console.log(`docs-drift: allowed via DOCS_DRIFT_ALLOW (missing: ${missing.join(', ')})`)
    return
  }
  console.error('docs-drift: configuration sources changed without updating:')
  for (const file of missing) console.error(`  - ${file}`)
  console.error('Update them in this branch, or record in the task why no docs change applies and set DOCS_DRIFT_ALLOW=1.')
  process.exit(1)
}

if (import.meta.main) main()
