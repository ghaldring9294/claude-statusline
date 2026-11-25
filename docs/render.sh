#!/usr/bin/env bash
# Regenerate docs/states.svg from statusline.sh's real output, so the README
# picture can't drift from the script. Usage: docs/render.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../statusline.sh"
out="$here/states.svg"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Throwaway repo named my-app, pushed to a local bare remote.
git init -q --bare -b main "$tmp/origin.git"
repo="$tmp/my-app"
git init -q -b main "$repo"
g() { git -C "$repo" "$@"; }
g config user.email t@t; g config user.name t
echo a > "$repo/f"; g add f; g commit -qm 1
g remote add origin "$tmp/origin.git"; g push -q -u origin main 2>/dev/null

render() { # <dir> <remaining %> [script]
  printf '{"model":{"display_name":"Opus 5.5 (1M context)"},"workspace":{"current_dir":"%s"},"context_window":{"remaining_percentage":%s}}' "$1" "$2" \
    | env -i PATH=/usr/bin:/bin bash "${3:-$script}"
}

labels=() lines=()
add() { labels+=("$1"); lines+=("$2"); }

add "Plenty of context, clean" "$(render "$repo" 78)"
echo b >> "$repo/f"
add "Over half used, uncommitted" "$(render "$repo" 41)"
g checkout -q -b feature/login; g commit -qam 2; g push -q -u origin feature/login 2>/dev/null
echo c >> "$repo/f"; g commit -qam 3; echo d >> "$repo/f"; g commit -qam 4; echo e >> "$repo/f"
add "Running low, 2 unpushed" "$(render "$repo" 12)"
mkdir -p "$tmp/Downloads"
add "Outside a git repo" "$(render "$tmp/Downloads" 95)"
sed 's#for candidate in [^;]*;#for candidate in /nonexistent/jq;#' "$script" > "$tmp/nojq.sh"
add "Something is wrong" "$(printf '{}' | env -i PATH=/bin bash "$tmp/nojq.sh")"

# ANSI -> SVG tspans. Only the script's own codes appear: 31/32/33 and reset.
to_svg() {
  sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
      -e $'s/\033\\[32m/<tspan class="g">/g' \
      -e $'s/\033\\[33m/<tspan class="y">/g' \
      -e $'s/\033\\[31m/<tspan class="r">/g' \
      -e $'s/\033\\[0m/<\\/tspan>/g'
}

row_h=34 pad=20 label_w=210 width=740
height=$(( pad * 2 + row_h * ${#lines[@]} - 10 ))
{
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n' "$width" "$height" "$width" "$height"
  cat <<'EOF'
<style>
  text { font: 14px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; fill: #e6edf3; }
  .label { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; fill: #8b949e; }
  .g { fill: #3fb950; } .y { fill: #d29922; } .r { fill: #f85149; }
</style>
EOF
  printf '<rect width="100%%" height="100%%" rx="8" fill="#0d1117"/>\n'
  for i in "${!lines[@]}"; do
    y=$(( pad + 14 + i * row_h ))
    printf '<text class="label" x="%d" y="%d">%s</text>\n' "$pad" "$y" "${labels[$i]}"
    printf '<text x="%d" y="%d" xml:space="preserve">%s</text>\n' "$(( pad + label_w ))" "$y" "$(printf '%s' "${lines[$i]}" | to_svg)"
  done
  printf '</svg>\n'
} > "$out"

echo "wrote $out (${#lines[@]} states)"
