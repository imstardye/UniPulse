cask "unipulse" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/imstardye/UniPulse/releases/download/v#{version}/UniPulse-LINE-#{version}-macos-#{arch}.dmg"
  end

  name "UniPulse"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/imstardye/UniPulse"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "UniPulse.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/UniPulse.app"],
        writable_paths: ["UniPulse.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.imstardye.unipulse"

  zap trash: [
    "~/Library/Application Support/com.imstardye.unipulse",
    "~/Library/Caches/com.imstardye.unipulse",
    "~/Library/Preferences/com.imstardye.unipulse.plist",
    "~/Library/Saved Application State/com.imstardye.unipulse.savedState",
  ]
end
