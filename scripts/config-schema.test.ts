import { describe, expect, test } from 'bun:test'
import { validate, validateVersion1 } from './config-schema'

const base = (): any => ({
  version: 2,
  appearance: { family: 'native', mode: 'system', accent: '#D6F58A', material: 'native' },
  layout: { height: 32, padding: 12, notchGap: 10 },
  left: ['workspaces', 'front-app'],
  right: ['battery', 'clock', 'network', 'volume'],
})

describe('validate', () => {
  test('accepts the default shape', () => {
    expect(() => validate(base())).not.toThrow()
  })

  test('accepts a custom palette override', () => {
    const config = base()
    config.appearance = {
      family: 'gruvbox',
      mode: 'dark',
      accent: '#D6F58A',
      material: 'opaque',
      palette: { foreground: '#EBDBB2', background: '#282828', selected: '#458588' },
    }
    expect(() => validate(config)).not.toThrow()
  })

  test('accepts a palette that overrides accent', () => {
    const config = base()
    config.appearance = { ...config.appearance, palette: { accent: '#B7CEFF' } }
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects a palette that is not an object', () => {
    const config = base()
    config.appearance = { ...config.appearance, palette: '#EBDBB2' }
    expect(() => validate(config)).toThrow('appearance.palette: expected object')
  })

  test('rejects an unknown palette token', () => {
    const config = base()
    config.appearance = { ...config.appearance, palette: { highlight: '#EBDBB2' } }
    expect(() => validate(config)).toThrow('appearance.palette: unknown field highlight')
  })

  test('rejects a palette token that is not six-digit hex', () => {
    const config = base()
    config.appearance = { ...config.appearance, palette: { foreground: 'EBDBB2' } }
    expect(() => validate(config)).toThrow('appearance.palette.foreground: expected six-digit hex')
  })

  test('rejects a duplicate item across groups', () => {
    const config = base()
    config.right = ['workspaces', 'clock']
    expect(() => validate(config)).toThrow('left/right: an item may appear in only one group')
  })

  test('rejects an unknown widget namespace', () => {
    const config = base()
    config.widgets = { weather: {} }
    expect(() => validate(config)).toThrow('widgets: unknown field weather')
  })

  test('accepts the keep-awake preference', () => {
    const config = base()
    config.keepAwake = { remember: true, isActive: true }
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects an unknown keep-awake field', () => {
    const config = base()
    config.keepAwake = { forever: true }
    expect(() => validate(config)).toThrow('keepAwake: unknown field forever')
  })

  test('rejects a non-boolean keep-awake field', () => {
    const config = base()
    config.keepAwake = { remember: 'yes' }
    expect(() => validate(config)).toThrow('keepAwake.remember: expected boolean')
  })

  test('accepts the text size and font', () => {
    const config = base()
    config.text = { size: 16, font: 'Helvetica' }
    expect(() => validate(config)).not.toThrow()
  })

  test('accepts an empty font as the system default', () => {
    const config = base()
    config.text = { size: 14, font: '' }
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects an out-of-range text size', () => {
    const config = base()
    config.text = { size: 80 }
    expect(() => validate(config)).toThrow('text.size: expected 10–20')
  })

  test('rejects a non-string font', () => {
    const config = base()
    config.text = { font: 12 }
    expect(() => validate(config)).toThrow('text.font: expected string')
  })

  test('rejects an unknown text field', () => {
    const config = base()
    config.text = { weight: 'bold' }
    expect(() => validate(config)).toThrow('text: unknown field weight')
  })

  test('accepts the menu-bar detection opt-in', () => {
    const config = base()
    config.menuBar = { trustAccessibilityProbe: true }
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects an unknown menu-bar field', () => {
    const config = base()
    config.menuBar = { alwaysBelow: true }
    expect(() => validate(config)).toThrow('menuBar: unknown field alwaysBelow')
  })

  test('rejects a non-boolean menu-bar field', () => {
    const config = base()
    config.menuBar = { trustAccessibilityProbe: 'yes' }
    expect(() => validate(config)).toThrow('menuBar.trustAccessibilityProbe: expected boolean')
  })

  test('accepts the app-icon opt-in', () => {
    const config = base()
    config.showAppIcon = true
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects a non-boolean app-icon opt-in', () => {
    const config = base()
    config.showAppIcon = 'yes'
    expect(() => validate(config)).toThrow('showAppIcon: expected boolean')
  })

  test('accepts the workspace dot toggles', () => {
    const config = base()
    config.showOccupiedDot = false
    config.showEmptyDot = true
    expect(() => validate(config)).not.toThrow()
  })

  test('rejects a non-boolean workspace dot toggle', () => {
    const config = base()
    config.showOccupiedDot = 'no'
    expect(() => validate(config)).toThrow('showOccupiedDot: expected boolean')
  })

  test('rejects an unknown option in a known widget', () => {
    const config = base()
    config.widgets = { clock: { timezone: 'UTC' } }
    expect(() => validate(config)).toThrow('widgets.clock: unknown field timezone')
  })

  test('accepts either supported workspace adapter', () => {
    const aero = base()
    aero.widgets = { workspaces: { adapter: 'aerospace' } }
    expect(() => validate(aero)).not.toThrow()

    const yabai = base()
    yabai.widgets = { workspaces: { adapter: 'yabai' } }
    expect(() => validate(yabai)).not.toThrow()
  })

  test('rejects an unknown workspace adapter', () => {
    const config = base()
    config.widgets = { workspaces: { adapter: 'amphibian' } }
    expect(() => validate(config)).toThrow('widgets.workspaces.adapter: expected aerospace | yabai')
  })

  test('rejects options for an item that is not placed', () => {
    const config = base()
    config.left = ['workspaces']
    config.widgets = { 'front-app': { showIcon: false } }
    expect(() => validate(config)).toThrow('widgets.front-app: not placed on left or right')
  })

  test('rejects a version 1 document as a version 2 example', () => {
    expect(() => validate({ ...base(), version: 1 })).toThrow('version: expected 2')
  })
})

const v1 = (): any => ({
  version: 1,
  appearance: { family: 'native', mode: 'system', accent: '#D6F58A', material: 'native' },
  layout: { height: 32, padding: 12, notchGap: 10 },
  status: ['battery', 'clock', 'network', 'volume'],
})

describe('validateVersion1', () => {
  test('accepts the documented pre-release shape', () => {
    expect(() => validateVersion1(v1())).not.toThrow()
  })

  test('accepts the version 1 starter fixtures', async () => {
    for (const name of ['v1-default.json', 'v1-focus.json']) {
      const fixture = await Bun.file(new URL(`../examples/migrations/${name}`, import.meta.url)).json()
      expect(() => validateVersion1(fixture)).not.toThrow()
    }
  })

  test('rejects a document that is not version 1', () => {
    expect(() => validateVersion1({ ...v1(), version: 2 })).toThrow('version: expected 1')
  })

  test('rejects an unknown root field', () => {
    expect(() => validateVersion1({ ...v1(), mystery: true })).toThrow('root: unknown field mystery')
  })

  test('rejects a status array that repeats the left workspaces item', () => {
    expect(() => validateVersion1({ ...v1(), status: ['workspaces', 'clock'] }))
      .toThrow('left/right: an item may appear in only one group')
  })

  test('rejects unknown workspace options at the root', () => {
    expect(() => validateVersion1({ ...v1(), workspaces: { mystery: true } }))
      .toThrow('workspaces: unknown field mystery')
  })
})
