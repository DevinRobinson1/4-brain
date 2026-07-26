#!/usr/bin/env bash
# Install the 4-brain skill for Claude Code (macOS / Linux).
#   ./install.sh          symlink (repo stays source of truth; git pull updates it)
#   ./install.sh --copy   independent copy
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/skill"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$DEST_DIR/4-brain"
MODE="${1:-symlink}"

[ -f "$SRC/SKILL.md" ] || { echo "error: $SRC/SKILL.md not found — run from the repo." >&2; exit 1; }
mkdir -p "$DEST_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  echo "removing existing $DEST"
  rm -rf "$DEST"
fi

if [ "$MODE" = "--copy" ]; then
  cp -R "$SRC" "$DEST"
  echo "installed (copy) -> $DEST"
else
  ln -s "$SRC" "$DEST"
  echo "installed (symlink) -> $DEST -> $SRC"
fi

echo
echo "Brains detected:"
for cli in codex gemini grok; do
  if command -v "$cli" >/dev/null 2>&1; then
    printf '  %-7s %s\n' "$cli" "$("$cli" --version 2>&1 | head -1)"
  else
    printf '  %-7s not found (that route will be skipped)\n' "$cli"
  fi
done
echo
echo "Done. Start Claude Code and run: /4-brain"
