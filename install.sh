#!/usr/bin/env bash
# Install: symlink statusline.sh into ~/.claude and print the settings.json snippet.
# Idempotent — safe to re-run. Never edits settings.json for you (that file is yours).
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
dest="$HOME/.claude/statusline.sh"

mkdir -p "$HOME/.claude"
ln -sfn "$src" "$dest"
echo "linked $dest -> $src"

command -v jq >/dev/null || echo "WARNING: jq not found — the statusline needs it (brew install jq)."

cat <<'EOF'

Add this to ~/.claude/settings.json (merge into any existing top-level keys):

  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\""
  }
EOF
