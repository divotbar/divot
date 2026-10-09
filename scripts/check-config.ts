import { readdir } from 'node:fs/promises'
import { validate, validateVersion1 } from './config-schema'

for (const file of await readdir(new URL('../examples/', import.meta.url))) {
  if (!file.endsWith('.json')) continue
  validate(await Bun.file(new URL(`../examples/${file}`, import.meta.url)).json())
  console.log(`Validated ${file}`)
}

// Version 1 starter fixtures the native loader migrates to version 2.
for (const file of await readdir(new URL('../examples/migrations/', import.meta.url))) {
  if (!file.endsWith('.json')) continue
  validateVersion1(await Bun.file(new URL(`../examples/migrations/${file}`, import.meta.url)).json())
  console.log(`Validated v1 migration fixture ${file}`)
}
