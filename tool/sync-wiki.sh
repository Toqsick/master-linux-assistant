#!/bin/bash
# Mirrors docs/wiki/*.md into the repository's GitHub wiki.
#
# docs/wiki/ is the source of truth: the pages are plain markdown with
# GitHub-wiki naming, so they can be copied 1:1 into the wiki repository.
# The direction is one-way — a page edited directly in the GitHub wiki is
# overwritten by the next run. Edit in docs/wiki/ by PR, then sync.
#
# The mirror is exact: a page that no longer exists in docs/wiki/ is
# deleted from the wiki. Preview is the default; nothing reaches GitHub
# without --push.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="docs/wiki"
REMOTE=origin
PUSH=0

usage() {
  cat <<'EOF'
Mirror docs/wiki/*.md into the repository's GitHub wiki.

Usage:
  tool/sync-wiki.sh                     show what would change (default)
  tool/sync-wiki.sh --push              mirror for real
  tool/sync-wiki.sh --remote upstream   use a remote other than origin
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1 ;;
    --remote)
      shift
      REMOTE="${1:-}"
      [ -n "$REMOTE" ] || { echo "--remote needs a remote name" >&2; exit 2; }
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || { echo "git not found" >&2; exit 1; }

if ! compgen -G "$ROOT/$SRC/*.md" >/dev/null; then
  echo "no *.md pages in $SRC — refusing to run" >&2
  exit 1
fi

if ! URL="$(git -C "$ROOT" remote get-url "$REMOTE" 2>/dev/null)"; then
  echo "no such remote: $REMOTE" >&2
  exit 1
fi

SLUG="$(printf '%s' "$URL" |
  sed -E 's#^git@[^:]+:##; s#^[a-z+]+://[^/]+/##; s#\.git$##; s#/$##')"

case "$SLUG" in
  */*) ;;
  *)
    echo "cannot derive owner/repo from $REMOTE = $URL" >&2
    exit 1
    ;;
esac

SRC_REV="$(git -C "$ROOT" rev-parse --short HEAD)"
if [ -n "$(git -C "$ROOT" status --porcelain -- "$SRC")" ]; then
  SRC_REV="$SRC_REV-dirty"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "source: $SRC @ $SRC_REV"
echo "wiki:   https://github.com/$SLUG/wiki"
echo

git clone --quiet "https://github.com/$SLUG.wiki.git" "$WORK/wiki"
BRANCH="$(git -C "$WORK/wiki" symbolic-ref --short HEAD)"

cp "$ROOT/$SRC"/*.md "$WORK/wiki/"

while IFS= read -r page; do
  if [ ! -f "$ROOT/$SRC/$page" ]; then
    git -C "$WORK/wiki" rm --quiet -- "$page"
    echo "delete: $page"
  fi
done < <(git -C "$WORK/wiki" ls-files -- '*.md')

git -C "$WORK/wiki" add -A

if git -C "$WORK/wiki" diff --cached --quiet; then
  echo "wiki already matches $SRC — nothing to do."
  exit 0
fi

echo "changes to mirror:"
git -C "$WORK/wiki" diff --cached --stat

if [ "$PUSH" -eq 0 ]; then
  echo
  echo "preview only — re-run with --push to mirror."
  exit 0
fi

git -C "$WORK/wiki" commit --quiet -m "sync: $SRC @ $SRC_REV"

if command -v gh >/dev/null 2>&1; then
  git -c credential.helper='!gh auth git-credential' \
    -C "$WORK/wiki" push --quiet origin "$BRANCH"
else
  git -C "$WORK/wiki" push --quiet origin "$BRANCH"
fi

echo
echo "mirrored to https://github.com/$SLUG/wiki"
