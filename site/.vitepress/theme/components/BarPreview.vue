<script setup>
import { computed, ref } from 'vue'
defineProps({ compact: Boolean })
const active = ref(2)
const preset = ref('alpine')
const presets = [{ id: 'alpine', name: 'Alpine' }, { id: 'midnight', name: 'After dark' }, { id: 'focus', name: 'Just enough' }]
const name = computed(() => ['Write', 'Build', 'Browse', 'Listen'][active.value - 1])
</script>

<template>
  <div class="bar-demo" :class="[`preset-${preset}`, { compact }]">
    <div class="mock-bar" aria-label="Interactive concept preview of Divot">
      <div class="workspace-side">
        <span class="mini-mark" aria-hidden="true">◒</span>
        <div class="workspace-buttons" aria-label="Demo workspaces">
          <button v-for="n in 4" :key="n" :aria-label="`Preview workspace ${n}`" :aria-pressed="active === n" :class="{ selected: active === n }" @click="active = n">{{ String(n).padStart(2, '0') }}</button>
        </div>
        <span class="workspace-name">{{ name }}</span>
      </div>
      <div class="camera-space" aria-hidden="true"><span></span></div>
      <div class="status-side">
        <span v-if="preset !== 'focus'" class="app-name">↗ &nbsp; Finder</span>
        <svg v-if="preset !== 'focus'" class="wifi" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-label="Illustrative Wi-Fi status" role="img"><path d="M3 8a15 15 0 0 1 18 0M6 12a10 10 0 0 1 12 0M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>
        <span v-if="preset !== 'focus'" class="battery"><span aria-hidden="true"></span>84%</span>
        <span class="demo-clock">Sat 10 Oct &nbsp; 09:41</span>
      </div>
    </div>
    <div v-if="!compact" class="preview-controls">
      <span class="preview-label">A little room to play</span>
      <div class="preset-buttons" aria-label="Preview appearance">
        <button v-for="item in presets" :key="item.id" :aria-pressed="preset === item.id" :class="{ selected: preset === item.id }" @click="preset = item.id">{{ item.name }}</button>
      </div>
      <span class="preview-note" aria-live="polite">Concept preview · {{ name }}</span>
    </div>
  </div>
</template>
