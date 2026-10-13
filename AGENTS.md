# WhisperType Development Guidelines

## UserDefaults Keys

Always use `UserDefaultsKeys` instead of magic strings. All keys are defined in `WhisperType/Extensions/UserDefaults.swift`.

```swift
// ✅ Good
UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoPasteText)

// ❌ Bad
UserDefaults.standard.bool(forKey: "autoPasteText")
```

When adding a new key, add it to the `UserDefaultsKeys` struct first.

## Transcription

Audio blocks are sent directly to Groq (`WhisperType/Helpers/Uploading.swift`) using the user's own API key, stored in the Keychain (`WhisperType/Helpers/Keychain.swift`). The app has no backend of its own.

## Build & Deploy

The app is distributed through GitHub only, not the App Store.

- **Ruby version**: managed by mise (see `.mise.toml`)
- **Install dependencies**: `mise install && bundle install`
- **Bump build number**: `bundle exec fastlane mac bump`
- **Bump patch version**: `bundle exec fastlane mac bump_patch`
