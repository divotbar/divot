import DefaultTheme from 'vitepress/theme'
import Layout from './Layout.vue'
import BarPreview from './components/BarPreview.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  Layout,
  enhanceApp({ app }) { app.component('BarPreview', BarPreview) }
}
