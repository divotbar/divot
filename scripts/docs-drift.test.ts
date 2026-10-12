import { describe, expect, test } from 'bun:test'
import { findDrift } from './docs-drift'

const configSource = 'macos/Sources/DivotCore/Configuration/DivotConfiguration.swift'

describe('findDrift', () => {
  test('ignores changes that are not configuration sources', () => {
    expect(findDrift(['AGENTS.md', 'site/guide/build.md'])).toEqual({ sources: [], missing: [] })
  })

  test('flags a configuration change that updates neither doc', () => {
    const report = findDrift([configSource])
    expect(report.sources).toEqual([configSource])
    expect(report.missing).toEqual(['docs/configuration.md', 'site/reference/configuration.md'])
  })

  test('flags only the doc still missing', () => {
    const report = findDrift([configSource, 'docs/configuration.md'])
    expect(report.missing).toEqual(['site/reference/configuration.md'])
  })

  test('accepts a configuration change that updates both docs', () => {
    const report = findDrift([configSource, 'docs/configuration.md', 'site/reference/configuration.md'])
    expect(report.missing).toEqual([])
  })
})
