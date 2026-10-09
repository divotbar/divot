import { describe, expect, test } from 'bun:test'
import { validate } from './config-schema'

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
})
