<script setup>
import { FIRST_RELEASE_PUBLISHED, LATEST_RELEASE_URL } from '../.vitepress/release'
</script>

# Install Divot

Divot is pre-alpha. The release pipeline — the Release-mode build, the unsigned
DMG packaging with a drag-to-Applications layout, the GitHub Release workflow,
and the prepared Homebrew tap — is implemented in this repository, but **the
first release is not published yet**. There is no version tag and no GitHub
Release, so there is nothing to download and no version or checksum to quote.
You can still [build and run a local preview from source](./build) today.

<div v-if="FIRST_RELEASE_PUBLISHED" class="install-download-wrap">
  <a class="install-download" :href="LATEST_RELEASE_URL">Download the latest Divot DMG</a>
</div>
<div v-else class="install-pending">
  <p><strong>The first release is not published yet.</strong> There is no tag and no GitHub Release, so this page shows no download button, version, or checksum. <a href="./build">Build a local preview from source</a> to try the native app now, or read the <a href="./roadmap">roadmap</a> for the release gates.</p>
</div>

## Download and verify

<div v-if="FIRST_RELEASE_PUBLISHED">

Every published release attaches two files to its GitHub Release:

- `Divot.dmg` — the disk image. Open it and drag **Divot** into your
  Applications folder. It includes an `Applications` shortcut for exactly that.
- `Divot.dmg.sha256` — the SHA-256 checksum of the DMG.

To verify the download before opening it:

```sh
cd ~/Downloads
shasum -a 256 -c Divot.dmg.sha256
```

A line ending in `Divot.dmg: OK` means the file matches the checksum published
with the release. Download only from this project's GitHub Releases — never a
mirror or a re-uploaded copy.

</div>

<div v-else>

The first release is not published yet, so there is no disk image and no
checksum file to verify. Each release will publish `Divot.dmg` together with
its `Divot.dmg.sha256` checksum, and this section will then show the exact
`shasum` command to check the download. Get builds only from this project's
GitHub Releases — never a mirror or a re-uploaded copy.

</div>

Requirements: macOS 26+ on Apple silicon.

## First launch of the unsigned build

The pre-alpha builds are **ad-hoc signed** — they are not Developer ID signed
and not notarized, so macOS Gatekeeper treats them as from an unidentified
developer. The first time you open a downloaded copy:

1. Open the DMG and drag **Divot** into your Applications folder.
2. In Applications, **right-click (or Control-click) Divot** and choose **Open**.
3. Click **Open** in the confirmation dialog. You only do this once; after the
   first launch, a normal double-click works.
4. If macOS still blocks it, open **System Settings → Privacy & Security**,
   scroll to the message about Divot, and click **Open Anyway**.

Do not disable Gatekeeper or remove the quarantine attribute. These builds are
not notarized, and signed/notarized distribution is a separate, planned step
(see the [roadmap](./roadmap)). If the app will not open, see
[Troubleshooting](./troubleshooting).

## Accessibility permission

Divot uses the macOS Accessibility API only for the capabilities that need it,
such as observing a notched display's menu-bar frame. When Accessibility is not
already granted, the app asks macOS to show the prompt once at launch. Without
the grant the rest of the bar still runs, and the notched-display reading is
reported as indeterminate rather than guessed.

To grant or re-check it yourself:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Add **Divot** from Applications and turn it on.

The local preview and pre-alpha builds are ad-hoc signed, so repackaging a new
build changes its code signature and an older grant no longer matches it. If the
permission stops working after an update, remove the stale Divot row, then add
the current app again. `divot status --json` reports the Accessibility reading
and names the System Settings pane; it never grants a permission for you.

## Wi-Fi name and Location permission

The network icon works without any permission. Showing the **Wi-Fi network name**
(SSID) is the one thing that needs Location permission, because that is what
macOS requires to read the current network name. It stays off until you turn the
name on in Settings; if you deny the prompt, the settings row explains and links
to **System Settings → Privacy & Security → Location Services**, and the bar
shows the network icon without a name. Divot never reads the SSID while the
permission is off.

The same permission gates the **Wi-Fi popover** that opens when you
click the network item: it lists nearby networks, and without permission it shows
a short message with a button to the Location Services pane instead of an empty
list. Clicking a network joins it; a secured network asks for its password in a
Divot dialog, and the password is never written to Divot's configuration or logs.

See [Widgets](./widgets) for the network item and [Troubleshooting](./troubleshooting)
for the permission details.

## Install with Homebrew

Once the first release is published and the tap is populated, Homebrew users can
install the same unsigned build with:

```sh
brew install --cask divotbar/tap/divot
```

The cask lives in the separate [`divotbar/homebrew-tap`](https://github.com/divotbar/homebrew-tap)
tap and is generated from the GitHub Release assets, so it never hard-codes a
version or checksum. It installs the same ad-hoc-signed app and makes no
notarization claim. The cask is prepared but not installable until the first
release exists.

## Set up Divot with your AI

Divot is small enough to configure by hand, and every setting is exposed to
agents through the same validated `divot` command line. For a copy-pasteable
agent prompt and the full command list, see
[Set up Divot with your AI](./ai-setup). Then read
[Configuration](../reference/configuration) for the complete reference.
