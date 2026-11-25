# claude-statusline

A single-file [Claude Code](https://claude.com/claude-code) status line:

```
Opus 5.5 [████████░░ 92%] | repo (feature/branch)
```

- **Model** — display name, with the `(1M context)` suffix trimmed.
- **Context gauge** — a bar showing context *remaining* (it drains as the window
  fills), plus the percentage. Green > 50% left, yellow > 20%, red below.
  Uses Claude Code's own `context_window.remaining_percentage`; before the
  first reply it estimates from the transcript (1M for `[1m]` models, 200k
  otherwise).
- **Location** — repo directory and current git branch.

Purely presentational — it reads the status-line JSON on stdin and prints one
line. No cost tracking, no network, no state.

If something is wrong it says so instead of showing a misleading gauge:
`statusline: jq not found` or `statusline: could not parse input`.

## Requirements

- `jq` — included with macOS 15 and later. The script finds it in
  `/opt/homebrew/bin`, `/usr/local/bin` or `/usr/bin` even when Claude Code
  runs it with a minimal `PATH`.
- `git` (branch display degrades to just the repo name if unavailable)

## Install

If `jq --version` fails, install it first:

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
