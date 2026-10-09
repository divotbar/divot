import { readdir } from 'node:fs/promises'
import { validate } from './config-schema'

for (const file of await readdir(new URL('../examples/', import.meta.url))) {
  if (!file.endsWith('.json')) continue
  validate(await Bun.file(new URL(`../examples/${file}`, import.meta.url)).json())
  console.log(`Validated ${file}`)
}
