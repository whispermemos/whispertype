#!/usr/bin/env ruby

require "fileutils"
require "shellwords"
require "xcodeproj"

=begin
Builds a WhisperType release and, with --publish, ships it.
Builds the notarized DMG with build-dmg.sh, adds it to the Sparkle feed from gh-pages,
then publishes the DMG as a GitHub release and pushes the feed to GitHub Pages.
=end

Dir.chdir(File.expand_path("..", __dir__))

REPOSITORY = "whispermemos/whispertype"
KEY_ACCOUNT = "whispertype"
SITE = "build/update-site"
TOOLS = "build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"

def run(*args)
  puts "==> #{args.join(' ')}"
  system(*args) || abort("Command failed: #{args.first}")
end

def output(*args)
  `#{args.shelljoin}`.strip
end

is_publishing = ARGV.include?("--publish")

if is_publishing
  abort("Commit your changes before publishing.") unless output("git", "status", "--porcelain").empty?
  run("git", "fetch", "origin", "main")
  abort("Publish from main, pushed to origin.") unless output("git", "rev-parse", "HEAD") == output("git", "rev-parse", "origin/main")
end

settings = Xcodeproj::Project.open("WhisperType.xcodeproj").targets
  .find { |target| target.name == "WhisperType" }.build_settings("Release")
tag = "v#{settings.fetch('MARKETING_VERSION')}"
abort("#{tag} is already released. Bump the version first.") if system("gh", "release", "view", tag, "--repo", REPOSITORY, out: File::NULL, err: File::NULL)

unless File.executable?("#{TOOLS}/generate_appcast")
  run("xcodebuild", "-resolvePackageDependencies", "-project", "WhisperType.xcodeproj",
      "-scheme", "Release", "-derivedDataPath", "build/DerivedData")
end
public_key = output("/usr/libexec/PlistBuddy", "-c", "Print :SUPublicEDKey", "WhisperType/Info.plist")
abort("The Keychain's Sparkle key doesn't match SUPublicEDKey.") unless output("#{TOOLS}/generate_keys", "--account", KEY_ACCOUNT, "-p") == public_key

# Start from the published feed so older versions stay listed.
FileUtils.rm_rf(SITE)
remote = output("git", "remote", "get-url", "origin")
if system("git", "ls-remote", "--exit-code", "--heads", remote, "gh-pages", out: File::NULL)
  run("git", "clone", "--depth=1", "--branch=gh-pages", remote, SITE)
else
  run("git", "init", "-b", "gh-pages", SITE)
  run("git", "-C", SITE, "remote", "add", "origin", remote)
end

run("bash", "scripts/build-dmg.sh")
FileUtils.cp("build/release/WhisperType.dmg", SITE)
run("#{TOOLS}/generate_appcast", "--account", KEY_ACCOUNT,
    "--download-url-prefix", "https://github.com/#{REPOSITORY}/releases/download/#{tag}/",
    "--maximum-deltas", "0", "--maximum-versions", "3", SITE)
FileUtils.rm("#{SITE}/WhisperType.dmg")

unless is_publishing
  puts "Built build/release/WhisperType.dmg and #{SITE}/appcast.xml. Publish with: bundle exec fastlane mac release"
  exit
end

# Release the DMG before the feed points at it.
run("gh", "release", "create", tag, "build/release/WhisperType.dmg", "--repo", REPOSITORY,
    "--title", "WhisperType #{tag.delete_prefix('v')}", "--generate-notes")
run("git", "-C", SITE, "add", "appcast.xml")
run("git", "-C", SITE, "commit", "-m", "Publish #{tag}")
# GitHub turns on Pages by itself the first time gh-pages is pushed.
run("git", "-C", SITE, "push", "origin", "gh-pages")

puts "Published #{tag}."
