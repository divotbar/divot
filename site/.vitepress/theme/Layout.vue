<script setup>
import { useData } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import Landing from './Landing.vue'
const { frontmatter } = useData()
</script>
<template><Landing v-if="frontmatter.layout === 'divot'" /><DefaultTheme.Layout v-else /></template>
