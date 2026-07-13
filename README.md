# claude-statusline

A single-file [Claude Code](https://claude.com/claude-code) status line:

```
Opus 4.8 [████████░░ 92%] | repo (feature/branch)
```

- **Model** — display name, with the `(1M context)` suffix trimmed.
- **Context gauge** — a bar showing context *remaining* (it drains as the window
  fills), plus the percentage. Green > 50% left, yellow > 20%, red below.
  The window size auto-detects: 1M for `[1m]` models, 200k otherwise.
- **Location** — repo directory and current git branch.

Purely presentational — it reads the status-line JSON on stdin and prints one
line. No cost tracking, no network, no state.

## Requirements

- `jq`
- `git` (branch display degrades to just the repo name if unavailable)

## Install

Install `jq` first if you don't have it (the status line needs it):

```sh
brew install jq
```

Then run:

```sh
./install.sh
```

This symlinks `statusline.sh` into `~/.claude/` and prints the `settings.json`
snippet to add. It does not edit `settings.json` for you.

## Manual install

Copy or symlink `statusline.sh` somewhere, then point Claude Code at it in
`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\""
  }
}
```
