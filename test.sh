#!/usr/bin/env bash
# Tests for statusline.sh. Builds throwaway repos and transcripts in a temp dir.
# Usage: ./test.sh   (prints ok/FAIL per case; exits non-zero on any failure)

here=$(cd "$(dirname "$0")" && pwd)
script="$here/statusline.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m'

# payload <current_dir> [extra JSON members]
payload() {
  printf '{"model":{"display_name":"Opus 5.5 (1M context)","id":"claude-opus-5-5"},"workspace":{"current_dir":"%s"}%s}' \
    "$1" "${2:+,$2}"
}

# check <name> <expected substring> <actual>
check() {
  case "$3" in
    *"$2"*) echo "ok   $1" ;;
    *) echo "FAIL $1: expected [$2] in [$3]"; fails=$((fails + 1)) ;;
  esac
}

run() { bash "$script"; }

# --- Context gauge -----------------------------------------------------------

# Claude Code's own figure wins: it knows the real window size for every model.
check "uses remaining_percentage" "${green}[██████░░░░ 63%]" \
  "$(payload /tmp '"context_window":{"remaining_percentage":63.7}' | run)"

# Thresholds: the colour is what you glance at, so the boundaries matter.
check "51% is green"  "${green}["  "$(payload /tmp '"context_window":{"remaining_percentage":51}' | run)"
check "50% is yellow" "${yellow}[" "$(payload /tmp '"context_window":{"remaining_percentage":50}' | run)"
check "21% is yellow" "${yellow}[" "$(payload /tmp '"context_window":{"remaining_percentage":21}' | run)"
check "20% is red"    "${red}["    "$(payload /tmp '"context_window":{"remaining_percentage":20}' | run)"

# Fallback for a resumed session before its first reply: the field is absent but
# the transcript already holds usage, so a full battery would be a lie.
# 150k used of 200k -> 25% left. The sidechain (subagent) turn is last but must
# be ignored, or the gauge would read the subagent's tiny context instead.
transcript="$tmp/t.jsonl"
printf '%s\n' \
  '{"message":{"usage":{"input_tokens":50000,"cache_creation_input_tokens":0,"cache_read_input_tokens":100000}}}' \
  '{"isSidechain":true,"message":{"usage":{"input_tokens":1}}}' > "$transcript"
check "transcript fallback, 200k window" "25%]" \
  "$(payload /tmp "\"transcript_path\":\"$transcript\"" | run)"
check "transcript fallback, 1M window" "85%]" \
  "$(payload /tmp "\"transcript_path\":\"$transcript\"" | sed 's#claude-opus-5-5#&[1m]#' | run)"

# New session, no usage anywhere yet: full battery.
check "null field, no transcript" "100%]" \
  "$(payload /tmp '"context_window":{"remaining_percentage":null}' | run)"

# --- Model ---------------------------------------------------------------------

check "trims (1M context) suffix" "Opus 5.5 ${green}" \
  "$(payload /tmp '"context_window":{"remaining_percentage":90}' | run)"

# A missing field must not shift the others (the reason for the \x1f separator).
check "missing model keeps other fields aligned" " 42%]" \
  "$(printf '{"workspace":{"current_dir":"/tmp"},"context_window":{"remaining_percentage":42}}' | run)"

# --- Failing loud ----------------------------------------------------------------

check "bad JSON"    "statusline: could not parse input" "$(printf 'not json' | run)"
check "empty input" "statusline: could not parse input" "$(printf '' | run)"

# No jq anywhere: hide it from PATH and point the fallback paths at nothing.
sed 's#for candidate in [^;]*;#for candidate in /nonexistent/jq;#' "$script" > "$tmp/nojq.sh"
check "jq not found" "statusline: jq not found" \
  "$(payload /tmp | env -i PATH=/bin bash "$tmp/nojq.sh")"

# --- Location ------------------------------------------------------------------

git init -q --bare -b main "$tmp/origin.git"
repo="$tmp/my repo"   # space in the path on purpose
git init -q -b main "$repo"
g() { git -C "$repo" "$@"; }
g config user.email t@t; g config user.name t
loc() { payload "$1" '"context_window":{"remaining_percentage":90}' | run | sed 's/.*| //'; }

check "repo with no commits" "my repo (main)" "$(loc "$repo")"
echo a > "$repo/f"; g add f; g commit -qm 1
g remote add origin "$tmp/origin.git"; g push -q -u origin main 2>/dev/null
check "clean and pushed" "my repo (main)" "$(loc "$repo")"

mkdir -p "$repo/sub/deep"
check "subfolder shows the repo, not the folder" "my repo (main)" "$(loc "$repo/sub/deep")"

echo b >> "$repo/f"
check "modified file marks *" "my repo (main*)" "$(loc "$repo")"
g commit -qam 2
check "unpushed commit marks ↑1" "my repo (main ↑1)" "$(loc "$repo")"
touch "$repo/new"
check "untracked file counts as dirty" "my repo (main* ↑1)" "$(loc "$repo")"
rm "$repo/new"

g checkout -qb feature/x
check "slash in branch, no upstream" "my repo (feature/x)" "$(loc "$repo")"
g checkout -q --detach
check "detached HEAD" "my repo (HEAD)" "$(loc "$repo")"

mkdir -p "$tmp/plain"
check "not a repo shows folder name" "| plain" "$(payload "$tmp/plain" | run)"

echo
[ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed"
exit "$fails"
