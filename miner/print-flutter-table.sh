#!/usr/bin/env bash
# Prints the Flutter apps found so far as an aligned Markdown table,
# most-installed first.
#
#   ./print-flutter-table.sh        every Flutter app in out/results.jsonl
#   ./print-flutter-table.sh fr     only apps in out/ranked-fr.json
#
# Reads out/results.jsonl directly; results only ever grow, so there is
# nothing to copy between runs. Save a snapshot with
#   ./print-flutter-table.sh fr > flutter-fr-$(date +%F).md
set -euo pipefail
cd "$(dirname "$0")"

results=out/results.jsonl
cc="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"

if [ -n "$cc" ]; then
  list="out/ranked-$cc.json"
  if [ ! -f "$list" ]; then
    echo "no list $list (have: $(ls out/ranked-*.json | sed 's|out/ranked-||;s|\.json||' | tr '\n' ' '))" >&2
    exit 1
  fi
  ids=$(jq -c '[.[].appId]' "$list")
else
  list=""
  ids=null
fi

# Rows: installs, title, package, Dart version, title length in characters
# (macOS awk counts bytes, so jq measures the title); then a summary line.
jq -rs --argjson ids "$ids" '
  (if $ids == null then . else
     ($ids | map({(.): true}) | add) as $in | map(select($in[.appId]))
   end) as $rows
  | ($rows | map(select(.flutter)) | sort_by(-(.installs // 0))[]
     | (.title // .appId) as $t
     | ["row", (.installs // 0), $t, .appId, (.dartVersion // "?"),
        ($t | length)] | @tsv),
    (["sum", ($rows | length),
      ($rows | map(select(.install == "installed"
                          or .install == "alreadyInstalled")) | length),
      ($ids | if . == null then "" else length end)] | @tsv)
' "$results" |
awk -F'\t' -v cc="$cc" '
  function commas(n,   s) {
    s = sprintf("%d", n)
    while (s ~ /[0-9][0-9][0-9][0-9]/) sub(/[0-9][0-9][0-9]([,]|$)/, ",&", s)
    return s
  }
  function spaces(n,   s) { s = ""; while (n-- > 0) s = s " "; return s }
  function pad(s, w, n) { return s spaces(w - (n == "" ? length(s) : n)) }
  function rule(w,   s) { s = ""; while (length(s) < w + 2) s = s "-"; return s }
  $1 == "sum" { checked = $2; inspected = $3; listed = $4; next }
  {
    rows++
    c[rows,1] = commas($2); c[rows,2] = $3; c[rows,3] = $4; c[rows,4] = $5
    n[rows,1] = length(c[rows,1]); n[rows,2] = $6
    n[rows,3] = length($4); n[rows,4] = length($5)
    for (i = 1; i <= 4; i++) if (n[rows,i] > w[i]) w[i] = n[rows,i]
  }
  END {
    split("Installs|App|Package|Dart", h, "|")
    for (i = 1; i <= 4; i++) if (length(h[i]) > w[i]) w[i] = length(h[i])
    line = "|"; for (i = 1; i <= 4; i++) line = line " " pad(h[i], w[i], "") " |"; print line
    line = "|"; for (i = 1; i <= 4; i++) line = line rule(w[i]) "|"; print line
    for (r = 1; r <= rows; r++) {
      line = "|"
      for (i = 1; i <= 4; i++) {
        cell = (i == 1) ? spaces(w[i] - n[r,i]) c[r,i] : pad(c[r,i], w[i], n[r,i])
        line = line " " cell " |"
      }
      print line
    }
    pct = inspected ? sprintf(" (%.1f%% of inspected)", 100 * rows / inspected) : ""
    if (cc != "")
      printf "\n%s: %d Flutter apps%s; %d of %d listed apps checked, %d inspected\n", \
        toupper(cc), rows, pct, checked, listed, inspected
    else
      printf "\nall: %d Flutter apps%s; %d apps checked, %d inspected\n", \
        rows, pct, checked, inspected
  }'
