import { defineConfig } from 'vitepress'

const baseUrl = 'https://divotbar.app/'

export default defineConfig({
  title: 'Divot',
  description: 'A quieter edge for your Mac. An open-source native macOS bar, designed around the notch.',
  base: '/',
  cleanUrls: true,
  appearance: 'dark',
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/mark.svg' }], ['meta', { name: 'theme-color', content: '#183d43' }]],
  sitemap: {
    hostname: baseUrl.slice(0, -1)
  },
  transformHead({ pageData }) {
    let path = pageData.relativePath
      .replace(/\.md$/, '')
      .replace(/\/index$/, '')

    if (path === 'index') {
      path = ''
    }

    const route = path ? '/' + path : '/'
    const canonicalUrl = baseUrl.slice(0, -1) + route
    return [
      ['link', { rel: 'canonical', href: canonicalUrl }]
    ]
  },
  themeConfig: {
    logo: '/mark.svg',
    nav: [{ text: 'Guide', link: '/guide/getting-started' }, { text: 'Customize', link: '/guide/customization' }, { text: 'Contribute', link: '/contributing/' }],
    sidebar: [{ text: 'Start here', items: [{ text: 'Introduction', link: '/guide/getting-started' }, { text: 'Build from source', link: '/guide/build' }, { text: 'Workspaces & displays', link: '/guide/workspaces' }] }, { text: 'Make it yours', items: [{ text: 'Customization', link: '/guide/customization' }, { text: 'Themes', link: '/guide/themes' }, { text: 'Widgets', link: '/guide/widgets' }, { text: 'Configuration reference', link: '/reference/configuration' }] }, { text: 'Project', items: [{ text: 'Performance', link: '/guide/performance' }, { text: 'Troubleshooting', link: '/guide/troubleshooting' }, { text: 'Roadmap', link: '/guide/roadmap' }, { text: 'Contributing', link: '/contributing/' }] }],
    search: { provider: 'local' },
    outline: [2, 3],
    footer: { message: 'Open source, by design. MIT licensed.', copyright: '© 2026 Divot contributors · Pre-alpha' }
  }
})
