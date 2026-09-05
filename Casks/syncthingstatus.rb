cask "syncthingstatus" do
  version "1.6.1"
  sha256 "b5f2475772164f2807fdba7256bc812562ab74813e6c89b85c3d9dc3d6835422"

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
