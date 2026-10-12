# Divot cask for the divotbar/homebrew-tap tap.
#
# `version`, `url`, and `sha256` are managed by the update workflow
# (`.github/workflows/divot-release.yml`), which reads them from the published
# GitHub Release assets. Do not edit them by hand.
#
# PLACEHOLDER-BEGIN
# No Divot release exists yet, so the values below are placeholders and this
# cask is not installable. The first tap update removes this note.
# PLACEHOLDER-END
cask "divot" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://example.invalid/divot/releases/download/v#{version}/Divot.dmg"
  name "Divot"
  desc "Workspace and status bar for the menu bar"
  homepage "https://divotbar.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Divot.app"

  caveats <<~EOS
    Divot is currently an unsigned build. On first launch, right-click the app
    in Applications and choose "Open", then confirm. Do not download a build
    from anywhere other than the official release page.
  EOS
end
