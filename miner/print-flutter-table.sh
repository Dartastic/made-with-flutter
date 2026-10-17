#!/usr/bin/env bash
# Filters out/results.jsonl to the Flutter apps (filter-flutter-in-out-json.sh
# writes flutter_apps2.json), then prints them as an aligned Markdown table,
# most-installed first.
set -euo pipefail
cd "$(dirname "$0")"

./filter-flutter-in-out-json.sh

jq -r 'sort_by(-(.installs // 0))[]
       | [(.installs // 0), (.title // .appId), .appId, (.dartVersion // "?")]
       | @tsv' flutter_apps2.json |
awk -F'\t' '
  function commas(n,   s) {
    s = sprintf("%d", n)
    while (s ~ /[0-9][0-9][0-9][0-9]/) sub(/[0-9][0-9][0-9]([,]|$)/, ",&", s)
    return s
  }
  function pad(s, w) { return sprintf("%-" w "s", s) }
  function rule(w,   s) { s = ""; while (length(s) < w + 2) s = s "-"; return s }
  {
    rows++
    c[rows,1] = commas($1); c[rows,2] = $2; c[rows,3] = $3; c[rows,4] = $4
    for (i = 1; i <= 4; i++) if (length(c[rows,i]) > w[i]) w[i] = length(c[rows,i])
  }
  END {
    split("Installs|App|Package|Dart", h, "|")
    for (i = 1; i <= 4; i++) if (length(h[i]) > w[i]) w[i] = length(h[i])
    line = "|"; for (i = 1; i <= 4; i++) line = line " " pad(h[i], w[i]) " |"; print line
    line = "|"; for (i = 1; i <= 4; i++) line = line rule(w[i]) "|"; print line
    for (r = 1; r <= rows; r++) {
      line = "|"
      for (i = 1; i <= 4; i++) {
        cell = (i == 1) ? sprintf("%" w[i] "s", c[r,i]) : pad(c[r,i], w[i])
        line = line " " cell " |"
      }
      print line
    }
    printf "\n%d Flutter apps\n", rows
  }'
