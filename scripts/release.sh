#!/usr/bin/env bash
# Publishes NotchBox <version> on GitHub Releases: make release VERSION=0.2.0
#
# From a clean main that matches origin/main, this sets the version in Resources/Info.plist, runs the
# tests, builds dist/NotchBox-<version>.zip, commits "Release <version>", tags v<version>, pushes both,
# creates the GitHub release with generated notes and uploads the zip as NotchBox.zip (the stable name
# install.sh downloads). Works while the repository is private too; install.sh only works while it is public.
#
# Token: $GITHUB_TOKEN if set, otherwise the github.com credential git already uses (Keychain).
# DRY_RUN=1 does every check and build but changes nothing in git or on GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"
VERSION="${1:-}"
DRY_RUN="${DRY_RUN:-}"

fail() { echo "error: $*" >&2; exit 1; }
say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "usage: make release VERSION=x.y.z"
cd "$ROOT"

# owner/name from the origin URL (https or ssh).
REPO="$(git remote get-url origin | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
[[ "$REPO" =~ ^[^/]+/[^/]+$ ]] || fail "origin is not a GitHub repository: $(git remote get-url origin)"

[ -z "$(git status --porcelain)" ] || fail "commit or stash your changes first"
[ "$(git branch --show-current)" = "main" ] || fail "switch to main first"
git fetch --quiet --tags origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "main is not the same as origin/main; pull or push first"
! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || fail "tag v$VERSION already exists"

CURRENT="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
say "NotchBox $CURRENT (build $BUILD) -> $VERSION (build $((BUILD + 1)))"

restore_plist() { git checkout -- "$PLIST"; }
[ -z "$DRY_RUN" ] || trap restore_plist EXIT
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $((BUILD + 1))" "$PLIST"

say "Testing"
make test >/dev/null
say "Building"
make dist >/dev/null
ZIP="$ROOT/dist/NotchBox-$VERSION.zip"
[ -f "$ZIP" ] || fail "$ZIP was not built"

if [ -n "$DRY_RUN" ]; then
  say "Dry run: built $ZIP; would commit, tag v$VERSION, push and publish to $REPO"
  exit 0
fi

TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  TOKEN="$(printf 'protocol=https\nhost=github.com\n\n' | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null | sed -n 's/^password=//p')"
fi
[ -n "$TOKEN" ] || fail "no GitHub token: set GITHUB_TOKEN or sign in to github.com with git"

say "Committing and tagging v$VERSION"
git commit --quiet -m "Release $VERSION" -- "$PLIST"
git tag -a "v$VERSION" -m "NotchBox $VERSION"
git push --quiet origin main "v$VERSION"

api() {
  curl -fsS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" "$@"
}

say "Creating the GitHub release"
BODY="$(cat <<EOF
Install or update with one command in Terminal:

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash
\`\`\`

Or download NotchBox.zip below, unzip it, move NotchBox.app to /Applications and run
\`xattr -dr com.apple.quarantine /Applications/NotchBox.app\` before opening it.
EOF
)"
PAYLOAD="$(TAG="v$VERSION" NAME="NotchBox $VERSION" BODY="$BODY" /usr/bin/python3 -c \
  'import json, os; print(json.dumps({"tag_name": os.environ["TAG"], "name": os.environ["NAME"], "body": os.environ["BODY"], "generate_release_notes": True}))')"
RELEASE="$(api -X POST "https://api.github.com/repos/$REPO/releases" -d "$PAYLOAD")"
RELEASE_ID="$(printf '%s' "$RELEASE" | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
RELEASE_URL="$(printf '%s' "$RELEASE" | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["html_url"])')"

say "Uploading NotchBox.zip"
api -X POST -H "Content-Type: application/zip" --data-binary "@$ZIP" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=NotchBox.zip" >/dev/null

say "Published $RELEASE_URL"
