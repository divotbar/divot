<script setup>
import { ref } from 'vue'
import { useData } from 'vitepress'
import BarPreview from './components/BarPreview.vue'
const mobileOpen = ref(false)
const { isDark } = useData()
</script>

<template>
  <div class="landing" :class="{ 'landing-dark': isDark }">
    <a class="skip-link" href="#main">Skip to content</a>
    <header class="landing-nav">
      <a class="wordmark" href="/" aria-label="Divot home"><svg viewBox="0 0 32 32" aria-hidden="true"><path d="M3 8h9v5a4 4 0 0 0 8 0V8h9v19H3z" fill="currentColor"/></svg>divot</a>
      <span class="nav-note">A native little thing for your Mac.</span>
      <button class="theme-toggle" :aria-pressed="isDark" :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'" @click="isDark = !isDark"><span aria-hidden="true">{{ isDark ? '☼' : '◐' }}</span> {{ isDark ? 'Light' : 'Dark' }}</button>
      <button class="mobile-toggle" :aria-expanded="mobileOpen" aria-controls="landing-links" @click="mobileOpen = !mobileOpen">{{ mobileOpen ? 'Close' : 'Menu' }}</button>
      <nav id="landing-links" :class="{ open: mobileOpen }" aria-label="Main navigation">
        <a href="/guide/install">Install</a><a href="/guide/getting-started">The guide</a><a href="/guide/customization">Make it yours</a><a class="nav-cta" href="/contributing/">Build with us <span aria-hidden="true">↗</span></a>
      </nav>
    </header>
    <main id="main">
      <section class="hero-intro">
        <div><p class="eyebrow"><span></span> OPEN SOURCE / NATIVE MACOS / IN THE MAKING</p><h1>A little more<br><em>headspace.</em></h1></div>
        <div class="hero-aside"><p>Your workspaces. Your essentials.<br>A quiet place for both, right at<br>the edge of your Mac.</p><a class="text-link" href="/guide/getting-started">Meet Divot <span aria-hidden="true">↗</span></a><span class="platform-note">Designed for macOS 26+ · Apple silicon</span></div>
      </section>
      <section class="landscape-section" aria-label="Divot concept on a Lake Tahoe desktop">
        <div class="landscape">
          <img class="tahoe-photo" src="/tahoe.jpg" alt="Pine trees framing Lake Tahoe and distant Sierra Nevada mountains" width="1920" height="1280" fetchpriority="high" />
          <div class="desktop-preview"><BarPreview compact /></div>
          <div class="landscape-caption"><span>LESS IN THE WAY.<br>MORE IN YOUR ELEMENT.</span><span class="coordinates">LAKE TAHOE, CA / NV<br>39°16′ N &nbsp; 119°56′ W</span></div>
        </div>
        <div class="image-footnote"><span>01 / A bar that gives the notch its space.</span><span>Interactive concept · click a workspace above</span></div>
      </section>
      <section class="manifesto section-grid">
        <p class="eyebrow">A PLACE FOR EVERYTHING</p>
        <div><h2>Two sides.<br>One clear head.</h2><p class="large-copy">Workspaces to the left of the camera.<br>The everyday things to the right.<br>The middle gets to breathe.</p><p class="body-copy">Divot is a new take on the macOS status bar. Built around the shape of your screen, with native interactions and a performance-first foundation. Small by intention. Yours by design.</p></div>
      </section>
      <section class="try-section" aria-labelledby="try-heading">
        <div class="section-heading"><div><p class="eyebrow">MAKE YOURSELF AT HOME</p><h2 id="try-heading">Your kind of quiet.</h2></div><a class="text-link" href="/guide/customization">Explore customization <span aria-hidden="true">↗</span></a></div>
        <div class="playground"><div class="playground-sky"><BarPreview /></div><div class="playground-bottom"><span>Workspaces on the left</span><span>Room for the camera</span><span>Essentials on the right</span></div></div>
      </section>
      <section class="principles">
        <article><span class="principle-number">01 / NATIVE AT HEART</span><h3>A Mac app.<br>Through and through.</h3><p>Swift. AppKit. System frameworks. A native foundation with careful focus, keyboard, and accessibility behavior in the plan.</p><a class="text-link" href="/guide/build">Under the hood <span aria-hidden="true">↗</span></a></article>
        <article><span class="principle-number">02 / LIGHT ON PURPOSE</span><h3>Let your Mac<br>get on with it.</h3><p>Event-driven updates, cached rendering, and no constant drawing loop. Performance budgets to meet, then measurements to share.</p><a class="text-link" href="/guide/performance">Our performance approach <span aria-hidden="true">↗</span></a></article>
        <article><span class="principle-number">03 / OPEN BY DESIGN</span><h3>A good default.<br>A thousand possibilities.</h3><p>Readable configuration. Useful guides. MIT-licensed code. A project you can understand, shape, and eventually make your own.</p><a class="text-link" href="/contributing/">Help shape Divot <span aria-hidden="true">↗</span></a></article>
      </section>
      <section class="field-guide section-grid">
        <p class="eyebrow">THE FIELD GUIDE</p>
        <div><h2>Settle in.<br>Find your own way.</h2><div class="guide-links"><a href="/guide/install"><span><small>01</small> Install Divot</span><span aria-hidden="true">↗</span></a><a href="/guide/getting-started"><span><small>02</small> Start here</span><span aria-hidden="true">↗</span></a><a href="/guide/workspaces"><span><small>03</small> Workspaces & displays</span><span aria-hidden="true">↗</span></a><a href="/guide/themes"><span><small>04</small> Colors, materials & moods</span><span aria-hidden="true">↗</span></a><a href="/guide/ai-setup"><span><small>05</small> Set up with your AI</span><span aria-hidden="true">↗</span></a><a href="/reference/configuration"><span><small>06</small> The configuration reference</span><span aria-hidden="true">↗</span></a></div></div>
      </section>
      <section class="closing"><p class="eyebrow">GOOD THINGS START SMALL</p><h2>Come make<br><em>a little space.</em></h2><p>Divot is just getting started. The docs, website, and native foundation<br class="desktop-break"> are here. The first public release is next.</p><a class="solid-link" href="/contributing/">Build with us <span aria-hidden="true">↗</span></a><span class="release-note">Pre-alpha · No downloadable app yet · <a href="/guide/install">Install options ↗</a></span></section>
    </main>
    <footer class="landing-footer"><a class="wordmark" href="/">divot</a><span>Made for the edge. Built in the open.</span><div><a href="/guide/roadmap">Roadmap</a><a href="/contributing/">MIT license</a><a href="/credits">Photo credits</a></div><small>© 2026 Divot contributors</small></footer>
  </div>
</template>
