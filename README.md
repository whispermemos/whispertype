# WhisperType

Dictation for macOS. Press a keyboard shortcut, speak, press it again, and WhisperType pastes the transcript into whatever text field you're in.

WhisperType is free and open source. It transcribes with [Groq](https://groq.com)'s hosted Whisper model, using your own Groq API key, so your recordings go straight from your Mac to Groq and nowhere else.

### [⬇️ Download WhisperType for macOS](https://github.com/whispermemos/whispertype/releases/latest/download/WhisperType.dmg)

Requires macOS 14.6 or later. Open the DMG and drag WhisperType into Applications. You'll also need a free [Groq API key](https://console.groq.com/keys).

## Features

- Global shortcut to start and stop recording, from any app
- Pastes the transcript into the active text field, or keeps it on the clipboard
- Press Return while recording to start a new paragraph
- Custom spellings for names and jargon the model gets wrong
- Language selection, or automatic detection
- History of past transcriptions, with retry for failed ones
- Microphone priority list, and optional lowering of system volume while recording
- Automatic update checks, with optional background download and installation

## Requirements

- macOS 14.6 or later
- A Groq API key — create one at [console.groq.com/keys](https://console.groq.com/keys)

## Setup

On first launch WhisperType walks you through:

1. **Microphone access**, to record you.
2. **Accessibility access**, to paste into other apps. Without it, transcripts are only copied to the clipboard.
3. **Your Groq API key**, stored in the macOS Keychain. You can change it later in Settings → API Key.

## Building from source

1. Open `WhisperType.xcodeproj` in Xcode.
2. In the WhisperType target's **Signing & Capabilities**, choose your own development team.
3. Select the **Debug** scheme and run.

Debug builds use the bundle ID `com.whispermemos.WhisperType.debug`, so they can be installed next to a release build.

Swift packages resolve automatically. Voice activity detection uses [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) with the Silero VAD model; both are checked into the repo (`sherpa-onnx.xcframework`, `Models/`).

### Releases

Releases use [Sparkle 2](https://sparkle-project.org/) for updates. The app checks a signed feed on [GitHub Pages](https://whispermemos.github.io/whispertype/appcast.xml), and downloads notarized DMGs from GitHub Releases. Settings → Updates controls automatic checks and automatic installation. Quitting or restarting during a recording stops capture and waits for transcription to finish, including the clipboard restoration delay. This also protects updates already staged for installation on quit. Debug builds never start the updater.

Install the Ruby dependencies with `mise install && bundle install`. The release Mac needs a Developer ID certificate, the notarization credentials described in `scripts/build-dmg.sh`, and an authenticated `gh` CLI with repository administration access for the initial GitHub Pages setup.

The Sparkle private signing key is stored in the release Mac's login Keychain under the `whispertype` account. Its public key is embedded as `SUPublicEDKey` in `WhisperType/Info.plist`. Keep the existing private key when moving to another Mac: Sparkle's `generate_keys --account whispertype -x <private-file>` and `-f <private-file>` export and import it. Keep exported private keys outside the repository. Sparkle's tools are available after package resolution in `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`.

```sh
bundle exec fastlane mac prepare_release  # build and sign locally for review
bundle exec fastlane mac release          # build and publish the release and update feed
```

`prepare_release` calls the existing `scripts/build-dmg.sh`, which archives and exports for Developer ID, notarizes and staples both the app and DMG, and verifies them with Gatekeeper. It then generates and verifies the signed feed. Outputs are `build/release/WhisperType.dmg` and `build/updates/appcast.xml`.

Before publishing, bump the version and build number, commit the changes, and push them to `main`. The `release` lane requires a clean checkout matching `origin/main`, rejects existing tags or draft releases and non-increasing build numbers, and checks the signing key before building. It publishes the DMG on a GitHub release, downloads and verifies the uploaded asset, then pushes the feed to `gh-pages`, enabling GitHub Pages automatically on the first release. Subsequent releases reuse the signed feed and keep up to three recent versions for each compatibility branch, including older macOS requirements.

If publication stops while the release is a draft, delete that draft with `gh release delete v<VERSION> --yes` before rebuilding. If the release is already public, recover using the original artifacts in `build/updates`: download its DMG and verify it against the `sparkle:edSignature` in that feed before pushing `build/update-site` with `git -C build/update-site push origin gh-pages`. If the uploaded DMG differs, replace it with `gh release upload v<VERSION> build/updates/WhisperType.dmg --clobber` and verify it again first. Enable Pages from `gh-pages` at `/` if this was the first release. Preserve the prepared files until recovery finishes.

Users of 1.0.9 and earlier must download the first updater-enabled release manually once. Future updates arrive through the app. To verify an installation, put an older updater-enabled release in Applications and use “Check for Updates…” after publishing the newer version.

### Version bumps

Fastlane lanes for bumping versions are available after `mise install && bundle install`:

```sh
bundle exec fastlane mac bump         # build number
bundle exec fastlane mac bump_patch   # patch version and build number
```

## How it works

While you record, WhisperType splits the audio into blocks of roughly 30 seconds, cutting at pauses in your speech (detected on-device), compresses each block to AAC, and sends it to Groq's `whisper-large-v3` transcription endpoint as soon as it's ready. When you stop, it joins the block transcripts in order and pastes the result. Your custom spellings are sent along as a prompt to steer the model.

## License

[MIT](LICENSE)
