fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac prepare_release

```sh
[bundle exec] fastlane mac prepare_release
```

Build the notarized DMG and update feed locally

### mac release

```sh
[bundle exec] fastlane mac release
```

Publish a GitHub release and its update feed

### mac bump

```sh
[bundle exec] fastlane mac bump
```

Bump build number, commit and push

### mac bump_patch

```sh
[bundle exec] fastlane mac bump_patch
```

Bump patch version and build number, commit and push

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
