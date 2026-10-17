jq -s 'map(select(.flutter))' out/results.jsonl > flutter_apps2.json
