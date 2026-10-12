/**
 * The single switch for the first public Divot release.
 *
 * No version tag and no GitHub Release exist yet. Task #0041 built the release
 * workflow, but pushing the first `v*.*.*` tag — and therefore publishing the
 * first unsigned DMG — is a maintainer action that has not happened. While this
 * is `false`, `site/guide/install.md` says plainly that the first release is not
 * published and renders no download button, version, or checksum.
 *
 * When the first unsigned release actually exists, flip this ONE line to
 * `true`. Nothing else changes: the page then renders the download button
 * pointed at `LATEST_RELEASE_URL`, which always resolves to the newest release.
 */
export const FIRST_RELEASE_PUBLISHED = false

/**
 * The stable GitHub "latest release" URL. It deliberately contains no version
 * or asset name, so it never needs updating between releases. Only render it
 * while `FIRST_RELEASE_PUBLISHED` is `true`.
 */
export const LATEST_RELEASE_URL = 'https://github.com/divotbar/divot/releases/latest'
