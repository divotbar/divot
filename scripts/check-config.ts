import { readdir } from 'node:fs/promises'

const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value)
function fields(value: unknown, keys: string[], path: string): asserts value is Record<string, unknown> {
  if (!object(value) || Object.keys(value).length !== keys.length || keys.some(key => !(key in value))) throw new Error(`${path}: expected exactly ${keys.join(', ')}`)
}
function oneOf(value: unknown, choices: string[], path: string) {
  if (typeof value !== 'string' || !choices.includes(value)) throw new Error(`${path}: expected ${choices.join(' | ')}`)
}
function range(value: unknown, min: number, max: number, path: string) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) throw new Error(`${path}: expected ${min}–${max}`)
}
export function validate(value: unknown) {
  fields(value, ['version', 'appearance', 'layout', 'workspaces', 'status'], 'root')
  if (value.version !== 1) throw new Error('version: expected 1')
  fields(value.appearance, ['mode', 'accent', 'material'], 'appearance')
  oneOf(value.appearance.mode, ['system', 'dark', 'light'], 'appearance.mode')
  oneOf(value.appearance.material, ['native', 'opaque'], 'appearance.material')
  if (typeof value.appearance.accent !== 'string' || !/^#[0-9a-f]{6}$/i.test(value.appearance.accent)) throw new Error('appearance.accent: expected six-digit hex')
  fields(value.layout, ['height', 'padding', 'notchGap'], 'layout')
  range(value.layout.height, 24, 40, 'layout.height')
  range(value.layout.padding, 0, 24, 'layout.padding')
  range(value.layout.notchGap, 0, 32, 'layout.notchGap')
  fields(value.workspaces, ['enabled', 'adapter', 'showEmpty'], 'workspaces')
  oneOf(value.workspaces.adapter, ['aerospace'], 'workspaces.adapter')
  for (const key of ['enabled', 'showEmpty']) if (typeof value.workspaces[key] !== 'boolean') throw new Error(`workspaces.${key}: expected boolean`)
  if (!Array.isArray(value.status) || new Set(value.status).size !== value.status.length) throw new Error('status: expected unique array')
  for (const item of value.status) oneOf(item, ['front-app', 'battery', 'clock'], 'status')
}
for (const file of await readdir(new URL('../examples/', import.meta.url))) {
  if (!file.endsWith('.json')) continue
  validate(await Bun.file(new URL(`../examples/${file}`, import.meta.url)).json())
  console.log(`Validated ${file}`)
}
