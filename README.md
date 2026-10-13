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

`scripts/build-dmg.sh` archives the Release scheme, signs it with a Developer ID certificate, notarizes and staples both the app and the DMG, and writes `build/release/WhisperType.dmg`. Attach that file to a GitHub release and the download link above picks it up. The script's header explains the one-time notarization setup.

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
