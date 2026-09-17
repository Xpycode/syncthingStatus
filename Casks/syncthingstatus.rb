cask "syncthingstatus" do
  version "1.6.2"
  sha256 "cd1e15a706605726edf613e9411829e8296d5cf2d0430c6e4362465dc6320f47"

  url "https://github.com/Xpycode/syncthingStatus/releases/download/v#{version}/syncthingStatus-v#{version}.dmg"
  name "syncthingStatus"
  desc "Menu bar app for monitoring Syncthing status"
  homepage "https://github.com/Xpycode/syncthingStatus"

  auto_updates true
  depends_on macos: :sequoia

  app "syncthingStatus.app"

  uninstall quit: "com.lucesumbrarum.syncthingStatus"

  caveats <<~EOS
    Requires macOS 15.5 or later and a running Syncthing instance.
    Syncthing is configured separately; this cask installs only the menu bar app.
  EOS
end
