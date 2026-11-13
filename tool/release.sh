#!/usr/bin/env bash
# Builds a signed APK on this machine and publishes it as a GitHub release, so
# releases don't need Actions minutes. The app offers it on next launch.
#
#   tool/release.sh 0.2.0 ["What changed"]
#
# Needs android/key.properties (see README "Updates") and the gh CLI signed in.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: tool/release.sh <major.minor.patch> [notes]}"
notes="${2:-}"
[[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { echo "Version must look like 0.2.0" >&2; exit 1; }
# Android only installs a higher versionCode, so derive it from the version
# (release.yml does the same): 0.2.0 -> 200, 1.4.12 -> 10412.
code=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))
tag="v$version"

[ -f android/key.properties ] || { echo "android/key.properties is missing; releases must use the release key." >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Commit or stash changes first." >&2; exit 1; }
git fetch -q origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] || { echo "Push or pull first: HEAD differs from its upstream." >&2; exit 1; }
if gh release view "$tag" >/dev/null 2>&1; then echo "$tag is already released." >&2; exit 1; fi

flutter build apk --release --build-name="$version" --build-number="$code"
apk=build/app/outputs/flutter-apk/app-release.apk

# Refuse anything not signed with the release key: phones would reject it as an update.
jbr="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
if ! java -version >/dev/null 2>&1 && [ -d "$jbr" ]; then export JAVA_HOME="$jbr" PATH="$jbr/bin:$PATH"; fi
sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
apksigner="$(ls -d "$sdk"/build-tools/*/apksigner | sort -V | tail -1)"
certs="$("$apksigner" verify --print-certs "$apk")"
[[ "$certs" == *"CN=Ioniq 6 Companion"* ]] || { echo "APK is not signed with the release key." >&2; exit 1; }

mkdir -p build/release
cp "$apk" build/release/ioniq6-companion.apk
if [ -n "$notes" ]; then set -- --notes "$notes"; else set -- --generate-notes; fi
gh release create "$tag" build/release/ioniq6-companion.apk \
  --target "$(git rev-parse HEAD)" --title "IONIQ 6 $tag" "$@"
echo "Released $tag (versionCode $code)."
