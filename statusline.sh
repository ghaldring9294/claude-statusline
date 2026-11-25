#!/usr/bin/env bash
# Claude Code status line: model | repo (branch) | context-window bar
# Reads the statusline JSON payload on stdin.

input=$(cat)

# Claude Code may run us with a minimal PATH, so also check the usual install spots.
JQ=$(command -v jq 2>/dev/null)
if [ -z "$JQ" ]; then
  for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    [ -x "$candidate" ] && JQ=$candidate && break
  done
fi
if [ -z "$JQ" ]; then
  printf 'statusline: jq not found\n'
  exit 0
fi

# One jq pass. Fields are joined with the unit separator (\x1f), not a tab:
# read collapses runs of whitespace delimiters, which would drop empty fields.
fields=$(printf '%s' "$input" | "$JQ" -r '[
    .model.display_name // "",
    .model.id // "",
    .workspace.current_dir // "",
    .transcript_path // "",
    (.context_window.remaining_percentage | if . == null then "" else floor end)
  ] | map(tostring) | join("\u001f")' 2>/dev/null)
if [ -z "$fields" ]; then
  printf 'statusline: could not parse input\n'
  exit 0
fi
IFS=$'\x1f' read -r model model_id dir transcript pct_left <<< "$fields"

repo=${dir##*/}
branch=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)

# Prefer Claude Code's own figure; it knows the real window size for every model.
# Fallback (field absent, e.g. before the first reply): estimate from the transcript.
if [ -z "$pct_left" ]; then
  case "$model_id" in
    *1m* | *1M* | *"[1m]"*) limit=1000000 ;;
    *) limit=200000 ;;
  esac

  used=0
  if [ -f "$transcript" ]; then
    used=$("$JQ" -s '
      map(select(.message.usage != null and (.isSidechain // false) == false))
      | last
      | if . == null then 0
        else (.message.usage.input_tokens
              + (.message.usage.cache_creation_input_tokens // 0)
              + (.message.usage.cache_read_input_tokens // 0))
        end' "$transcript" 2>/dev/null)
  fi
  [ -z "$used" ] && used=0

  pct_left=$(( (limit - used) * 100 / limit ))
fi
[ "$pct_left" -lt 0 ] && pct_left=0
[ "$pct_left" -gt 100 ] && pct_left=100

# Bar represents context REMAINING (drains as context fills).
width=10
filled=$(( pct_left * width / 100 ))
bar=""
i=0
while [ "$i" -lt "$width" ]; do
  if [ "$i" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
  i=$(( i + 1 ))
done

# Green > 50% left, yellow > 20%, red otherwise.
if [ "$pct_left" -gt 50 ]; then color=$'\033[32m'
elif [ "$pct_left" -gt 20 ]; then color=$'\033[33m'
else color=$'\033[31m'
fi
reset=$'\033[0m'

# Trim the "(1M context)" style suffix so the model name stays short.
short_model=${model% (*}

location="$repo"
[ -n "$branch" ] && location="$repo ($branch)"

printf '%s %s[%s %d%%]%s | %s\n' \
  "$short_model" \
  "$color" "$bar" "$pct_left" "$reset" \
  "$location"
