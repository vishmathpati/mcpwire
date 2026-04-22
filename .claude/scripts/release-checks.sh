#!/usr/bin/env bash
# release-checks.sh — preflight for the /release skill
# Prints what changed per release surface since the last tag, and surfaces
# anything that would block a release. Pure read-only.

set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }
hd()   { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }

hd "Environment"
command -v gh     >/dev/null && ok "gh"      || bad "gh CLI missing"
command -v brew   >/dev/null && ok "brew"    || bad "homebrew missing"
command -v bun    >/dev/null && ok "bun"     || bad "bun missing"
command -v npm    >/dev/null && ok "npm"     || bad "npm missing"
command -v swift  >/dev/null && ok "swift"   || warn "swift missing (only needed for mac releases)"

gh_status=$(gh auth status 2>&1 || true)
if echo "$gh_status" | grep -qi "Logged in"; then
  ok "gh authenticated"
else
  bad "gh not authenticated — run 'gh auth login'"
fi

if npm whoami >/dev/null 2>&1; then
  ok "npm logged in as $(npm whoami)"
else
  warn "npm not logged in — run 'npm login' before CLI release"
fi

hd "Git state"
BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then ok "on main"; else warn "on '$BRANCH' (not main)"; fi

if [ -z "$(git status --porcelain)" ]; then
  ok "working tree clean"
else
  warn "uncommitted changes present:"
  git status --porcelain | sed 's/^/    /'
fi

git fetch --quiet origin 2>/dev/null || true
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
if [ "$behind" = "0" ]; then ok "up to date with origin/main"; else warn "behind origin/main by $behind"; fi
if [ "$ahead" != "0" ]; then warn "ahead of origin/main by $ahead (unpushed commits)"; fi

hd "Mac app — changes since last mac-v* tag"
LAST_MAC=$(git tag -l 'mac-v*' --sort=-v:refname | head -1)
if [ -z "$LAST_MAC" ]; then
  warn "no mac tags found — every mac-app/ file is a candidate"
  MAC_FILES=$(git ls-files mac-app/ | head -20)
else
  ok "last mac tag: $LAST_MAC"
  MAC_FILES=$(git diff --name-only "$LAST_MAC"..HEAD -- mac-app/)
fi
if [ -z "$MAC_FILES" ]; then
  ok "no mac-app/ changes → nothing to release on mac"
else
  printf "  \033[36mfiles changed:\033[0m\n"
  echo "$MAC_FILES" | sed 's/^/    /'
fi

CURRENT_MAC_VERSION=$(grep -m1 "CFBundleShortVersionString" -A1 mac-app/build-app.sh 2>/dev/null | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/' || echo "?")
echo "  current build-app.sh version: $CURRENT_MAC_VERSION"

hd "npm CLI — changes since last cli-v* tag (fallback: last mac tag)"
LAST_CLI=$(git tag -l 'cli-v*' --sort=-v:refname | head -1)
[ -z "$LAST_CLI" ] && LAST_CLI="$LAST_MAC"
if [ -z "$LAST_CLI" ]; then
  warn "no tags at all — can't compute CLI diff"
  CLI_FILES=$(git ls-files src/ package.json | head -20)
else
  ok "last CLI reference tag: $LAST_CLI"
  CLI_FILES=$(git diff --name-only "$LAST_CLI"..HEAD -- src/ package.json)
fi
if [ -z "$CLI_FILES" ]; then
  ok "no src/ or package.json changes → nothing to publish to npm"
else
  printf "  \033[36mfiles changed:\033[0m\n"
  echo "$CLI_FILES" | sed 's/^/    /'
fi

if [ -f package.json ]; then
  LOCAL_CLI_VER=$(node -p "require('./package.json').version" 2>/dev/null || echo "?")
  echo "  local package.json version: $LOCAL_CLI_VER"
  PUBLISHED=$(npm view mcpbolt version 2>/dev/null || echo "?")
  echo "  published on npm:         $PUBLISHED"
  if [ "$LOCAL_CLI_VER" = "$PUBLISHED" ] && [ -n "$CLI_FILES" ]; then
    warn "CLI has changes but version not bumped from $PUBLISHED"
  fi
fi

hd "Homebrew cask"
TAP_DIR="/opt/homebrew/Library/Taps/vishmathpati/homebrew-mcpbolt"
if [ -d "$TAP_DIR" ]; then
  CASK_FILE="$TAP_DIR/Casks/mcpboltbar.rb"
  CASK_VER=$(grep -m1 '^\s*version "' "$CASK_FILE" | sed -E 's/.*version "([^"]+)".*/\1/')
  echo "  cask version in tap: $CASK_VER"
  if [ "$CASK_VER" != "$CURRENT_MAC_VERSION" ]; then
    warn "cask ($CASK_VER) out of sync with build-app.sh ($CURRENT_MAC_VERSION)"
  else
    ok "cask matches build-app.sh"
  fi
  (cd "$TAP_DIR" && git fetch --quiet origin 2>/dev/null; tap_behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?"); [ "$tap_behind" = "0" ] && echo "  tap up to date with origin/main" || warn "tap behind origin/main by $tap_behind — pull before editing")
else
  bad "tap not checked out at $TAP_DIR"
fi

hd "Landing"
if [ -d landing ]; then
  LANDING_FILES=$(git diff --name-only "$LAST_MAC"..HEAD -- landing/ 2>/dev/null || true)
  if [ -z "$LANDING_FILES" ]; then
    ok "no landing/ changes since $LAST_MAC (Vercel nothing to do)"
  else
    ok "landing changed — Vercel will auto-deploy on push to main:"
    echo "$LANDING_FILES" | sed 's/^/    /'
  fi
fi

echo
