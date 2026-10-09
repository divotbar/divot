const object = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

function shape(
  value: unknown,
  required: string[],
  optional: string[],
  path: string,
): asserts value is Record<string, unknown> {
  if (!object(value)) throw new Error(`${path}: expected object`)
  const allowed = [...required, ...optional]
  for (const key of Object.keys(value)) if (!allowed.includes(key)) throw new Error(`${path}: unknown field ${key}`)
  for (const key of required) if (!(key in value)) throw new Error(`${path}: expected ${key}`)
}
function oneOf(value: unknown, choices: string[], path: string) {
  if (typeof value !== 'string' || !choices.includes(value)) throw new Error(`${path}: expected ${choices.join(' | ')}`)
}
function hex(value: unknown, path: string) {
  if (typeof value !== 'string' || !/^#[0-9a-f]{6}$/i.test(value)) throw new Error(`${path}: expected six-digit hex`)
}
function range(value: unknown, min: number, max: number, path: string) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) throw new Error(`${path}: expected ${min}–${max}`)
}
function boolean(value: unknown, path: string) {
  if (typeof value !== 'boolean') throw new Error(`${path}: expected boolean`)
}
function flags(value: Record<string, unknown>, keys: string[], path: string) {
  for (const key of keys) if (key in value) boolean(value[key], `${path}.${key}`)
}

const FAMILIES = ['native', 'gruvbox', 'ayu', 'dracula', 'tokyo-night']
const ITEMS = ['workspaces', 'front-app', 'battery', 'network', 'volume', 'clock']
// Semantic color roles a custom palette may override, merged over the chosen
// family and variant. `accent` also exists at the appearance root; when both
// are present the palette value wins.
const PALETTE_TOKENS = ['foreground', 'background', 'accent', 'selected', 'occupied', 'error']

/** Versions the native loader knows how to migrate up to version 2. */
export const MIGRATABLE_VERSIONS = [1]

function group(value: unknown, path: string): string[] {
  if (!Array.isArray(value)) throw new Error(`${path}: expected array`)
  for (const item of value) oneOf(item, ITEMS, path)
  if (new Set(value).size !== value.length) throw new Error(`${path}: expected unique items`)
  return value as string[]
}

function appearance(value: unknown) {
  shape(value, ['family', 'mode', 'accent', 'material'], ['palette'], 'appearance')
  oneOf(value.family, FAMILIES, 'appearance.family')
  oneOf(value.mode, ['system', 'dark', 'light'], 'appearance.mode')
  oneOf(value.material, ['native', 'opaque'], 'appearance.material')
  hex(value.accent, 'appearance.accent')
  if ('palette' in value) {
    shape(value.palette, [], PALETTE_TOKENS, 'appearance.palette')
    for (const token of Object.keys(value.palette)) hex(value.palette[token], `appearance.palette.${token}`)
  }
}

function layout(value: unknown) {
  shape(value, ['height', 'padding', 'notchGap'], [], 'layout')
  range(value.height, 24, 40, 'layout.height')
  range(value.padding, 0, 24, 'layout.padding')
  range(value.notchGap, 0, 32, 'layout.notchGap')
}

function workspacesOptions(value: unknown, path: string) {
  shape(value, [], ['adapter', 'showEmpty', 'showAppIcons', 'showDetails', 'maxAppIconsPerWorkspace'], path)
  if ('adapter' in value) oneOf(value.adapter, ['aerospace', 'yabai'], `${path}.adapter`)
  flags(value, ['showEmpty', 'showAppIcons', 'showDetails'], path)
  if ('maxAppIconsPerWorkspace' in value) range(value.maxAppIconsPerWorkspace, 0, 32, `${path}.maxAppIconsPerWorkspace`)
}

function options(id: string, value: unknown) {
  const path = `widgets.${id}`
  switch (id) {
    case 'workspaces':
      workspacesOptions(value, path)
      return
    case 'front-app':
      shape(value, [], ['showIcon', 'showName'], path)
      flags(value, ['showIcon', 'showName'], path)
      return
    case 'clock':
      shape(value, [], ['weekday', 'date', 'seconds'], path)
      flags(value, ['weekday', 'date', 'seconds'], path)
      return
    default:
      shape(value, [], [], path)
  }
}

export function validate(value: unknown) {
  shape(value, ['version', 'appearance', 'layout', 'left', 'right'], ['widgets'], 'root')
  if (value.version !== 2) throw new Error('version: expected 2')
  appearance(value.appearance)
  layout(value.layout)
  const placed = [...group(value.left, 'left'), ...group(value.right, 'right')]
  if (new Set(placed).size !== placed.length) throw new Error('left/right: an item may appear in only one group')
  if ('widgets' in value) {
    shape(value.widgets, [], ITEMS, 'widgets')
    for (const id of Object.keys(value.widgets)) {
      if (!placed.includes(id)) throw new Error(`widgets.${id}: not placed on left or right`)
      options(id, value.widgets[id])
    }
  }
}

/**
 * Validate the pre-release version 1 starter shape the native loader migrates:
 * workspaces hard-coded on the left and a status-only right array, with the
 * workspace options at the document root. It never shipped and is not a
 * supported runtime version; this exists so the migration fixtures are checked
 * with the same rigor as the version 2 examples.
 */
export function validateVersion1(value: unknown) {
  shape(value, ['version', 'status'], ['appearance', 'layout', 'workspaces'], 'root')
  if (value.version !== 1) throw new Error('version: expected 1')
  const status = group(value.status, 'status')
  if (status.includes('workspaces')) throw new Error('left/right: an item may appear in only one group')
  if ('appearance' in value) appearance(value.appearance)
  if ('layout' in value) layout(value.layout)
  if ('workspaces' in value) workspacesOptions(value.workspaces, 'workspaces')
}
