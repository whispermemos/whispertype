#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "rexml/document"
require "xcodeproj"

=begin
Prepares or publishes WhisperType releases using the existing notarized DMG build.
Signs updates with the Keychain's whispertype Sparkle key and serves the feed on
GitHub Pages. The release becomes public before the feed is pushed to gh-pages.
=end

Dir.chdir(File.expand_path("..", __dir__))

REPOSITORY = "whispermemos/whispertype"
KEY_ACCOUNT = "whispertype"
FEED_URL = "https://whispermemos.github.io/whispertype/appcast.xml"
SITE = "build/update-site"
UPDATES = "build/updates"
TOOLS = "build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"

def run(*args)
  puts "==> #{args.join(' ')}"
  system(*args) || abort("Command failed: #{args.first}")
end

def capture(*args)
  stdout, stderr, status = Open3.capture3(*args)
  abort("#{args.first} failed: #{stderr}") unless status.success?
  stdout.strip
end

def api_json(path, *options)
  JSON.parse(capture("gh", "api", path, *options))
end

is_publishing = ARGV.delete("--publish")
abort("Usage: bundle exec ruby scripts/release.rb [--publish]") unless ARGV.empty?

repo_info = api_json("repos/#{REPOSITORY}")
if repo_info["has_pages"]
  pages = api_json("repos/#{REPOSITORY}/pages")
  unless pages["build_type"] != "workflow" && pages.dig("source", "branch") == "gh-pages" && pages.dig("source", "path") == "/"
    abort("GitHub Pages uses a different source. Set it to gh-pages / to serve #{FEED_URL}.")
  end
end

if is_publishing
  abort("Commit your changes before publishing a release.") unless capture("git", "status", "--porcelain").empty?
  abort("Publish releases from main.") unless capture("git", "branch", "--show-current") == "main"
  run("git", "fetch", "origin", "main")
  unless capture("git", "rev-parse", "HEAD") == capture("git", "rev-parse", "origin/main")
    abort("Push your release commit to origin/main before publishing.")
  end
end

project = Xcodeproj::Project.open("WhisperType.xcodeproj")
settings = project.targets.find { |target| target.name == "WhisperType" }
                  .build_configurations.find { |config| config.name == "Release" }.build_settings
version = settings.fetch("MARKETING_VERSION")
build_number = settings.fetch("CURRENT_PROJECT_VERSION").to_s
abort("Use a numeric build number.") unless build_number.match?(/\A\d+\z/)
tag = "v#{version}"
commit = capture("git", "rev-parse", "HEAD")

# Read all tags before building, so an API failure never looks like a missing release.
tags = api_json("repos/#{REPOSITORY}/git/matching-refs/tags/#{tag}")
abort("#{tag} already exists. Bump the version before releasing.") if tags.any? { |ref| ref["ref"] == "refs/tags/#{tag}" }
releases = api_json("repos/#{REPOSITORY}/releases", "--paginate", "--slurp").flatten
if releases.any? { |release| release["tag_name"] == tag }
  abort("#{tag} already has a GitHub release or draft. Finish recovering it, or delete the stale draft before preparing another DMG.")
end

unless File.executable?("#{TOOLS}/generate_keys")
  run("xcodebuild", "-resolvePackageDependencies", "-project", "WhisperType.xcodeproj",
      "-scheme", "Release", "-derivedDataPath", "build/DerivedData")
end
public_key = capture("#{TOOLS}/generate_keys", "--account", KEY_ACCOUNT, "-p")
unless public_key == capture("/usr/libexec/PlistBuddy", "-c", "Print :SUPublicEDKey", "WhisperType/Info.plist")
  abort("The Keychain signing key does not match the app's Sparkle public key.")
end

FileUtils.rm_rf([SITE, UPDATES])
FileUtils.mkdir_p([SITE, UPDATES])
run("git", "-C", SITE, "init", "-b", "gh-pages")
run("git", "-C", SITE, "remote", "add", "origin", capture("git", "remote", "get-url", "origin"))
branches = api_json("repos/#{REPOSITORY}/git/matching-refs/heads/gh-pages")
if branches.any? { |ref| ref["ref"] == "refs/heads/gh-pages" }
  run("git", "-C", SITE, "fetch", "--depth=1", "origin", "gh-pages")
  run("git", "-C", SITE, "checkout", "-B", "gh-pages", "FETCH_HEAD")
  FileUtils.cp("#{SITE}/appcast.xml", "#{UPDATES}/appcast.xml")
  feed = REXML::Document.new(File.read("#{UPDATES}/appcast.xml"))
  previous_builds = REXML::XPath.match(feed, "//sparkle:version", { "sparkle" => "http://www.andymatuschak.org/xml-namespaces/sparkle" })
  unless previous_builds.all? { |element| Integer(element.text) < Integer(build_number) }
    abort("The build number must be higher than every published update.")
  end
end

run("bash", "scripts/build-dmg.sh")
if is_publishing && (!capture("git", "status", "--porcelain").empty? || capture("git", "rev-parse", "HEAD") != commit)
  abort("Source changed during the build. Commit and push the changes before publishing.")
end
app_info = "build/release/WhisperType.app/Contents/Info.plist"
unless public_key == capture("/usr/libexec/PlistBuddy", "-c", "Print :SUPublicEDKey", app_info)
  abort("The Keychain signing key does not match the app's Sparkle public key.")
end

FileUtils.cp("build/release/WhisperType.dmg", "#{UPDATES}/WhisperType.dmg")
if File.exist?("#{UPDATES}/appcast.xml")
  run("#{TOOLS}/sign_update", "--account", KEY_ACCOUNT, "--verify", "#{UPDATES}/appcast.xml")
end
run("#{TOOLS}/generate_appcast", "--account", KEY_ACCOUNT,
    "--download-url-prefix", "https://github.com/#{REPOSITORY}/releases/download/#{tag}/",
    "--link", "https://github.com/#{REPOSITORY}/releases/tag/#{tag}",
    "--maximum-deltas", "0", "--maximum-versions", "3", "--versions", build_number, UPDATES)
run("#{TOOLS}/sign_update", "--account", KEY_ACCOUNT, "--verify", "#{UPDATES}/appcast.xml")

feed = REXML::Document.new(File.read("#{UPDATES}/appcast.xml"))
item = REXML::XPath.match(feed, "//item").find do |entry|
  entry.elements["sparkle:version"]&.text == build_number
end
abort("Generated feed is missing the new build.") unless item
enclosure = item.elements["enclosure"]
run("#{TOOLS}/sign_update", "--account", KEY_ACCOUNT, "--verify",
    "#{UPDATES}/WhisperType.dmg", enclosure.attributes["sparkle:edSignature"])

FileUtils.cp("#{UPDATES}/appcast.xml", "#{SITE}/appcast.xml")
FileUtils.touch("#{SITE}/.nojekyll")

unless is_publishing
  puts "Prepared #{version} (#{build_number}): build/release/WhisperType.dmg and #{UPDATES}/appcast.xml"
  puts "After committing and pushing, publish with: bundle exec fastlane mac release"
  exit
end

run("git", "-C", SITE, "add", "appcast.xml", ".nojekyll")
run("git", "-C", SITE, "commit", "-m", "Publish #{version} (#{build_number}) update feed")
run("gh", "release", "create", tag, "build/release/WhisperType.dmg",
    "--repo", REPOSITORY, "--target", commit, "--title", "WhisperType #{version}",
    "--generate-notes", "--draft")

# Publishing the download first prevents clients seeing a feed whose DMG is unavailable.
run("gh", "release", "edit", tag, "--repo", REPOSITORY, "--draft=false", "--latest")
FileUtils.mkdir_p("build/published-update")
run("gh", "release", "download", tag, "--repo", REPOSITORY,
    "--pattern", "WhisperType.dmg", "--dir", "build/published-update", "--clobber")
run("#{TOOLS}/sign_update", "--account", KEY_ACCOUNT, "--verify",
    "build/published-update/WhisperType.dmg", enclosure.attributes["sparkle:edSignature"])
run("git", "-C", SITE, "push", "origin", "gh-pages")

# Configure Pages only on its first release; refuse to overwrite a different site.
unless repo_info["has_pages"]
  run("gh", "api", "--method", "POST", "repos/#{REPOSITORY}/pages",
      "-f", "build_type=legacy", "-f", "source[branch]=gh-pages", "-f", "source[path]=/")
end

puts "Published #{tag}. GitHub Pages will deploy #{FEED_URL}."
