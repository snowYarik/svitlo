#!/usr/bin/env bash
# Phase 1 probe: fetch each source from the GitHub runner, record status/size/timing.
set -u
OUT="${1:-probe-out}"
mkdir -p "$OUT"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
echo "runner egress IP info:" > "$OUT/_runner.txt"
curl -sS --max-time 15 https://ipinfo.io/json >> "$OUT/_runner.txt" 2>&1 || true

probe() {
  local name="$1" url="$2"
  local body="$OUT/$name.body" hdr="$OUT/$name.headers"
  local meta
  meta=$(curl -sS -L --max-time 40 -A "$UA" -D "$hdr" -o "$body" \
    -w '%{http_code}\t%{size_download}\t%{time_total}\t%{url_effective}\t%{content_type}' "$url" 2>"$OUT/$name.err") || meta="curl_failed\t0\t0\t$url\t"
  printf '%s\t%s\t%s\n' "$name" "$meta" "$url" >> "$OUT/_summary.tsv"
}

printf 'name\thttp\tbytes\tseconds\tfinal_url\tcontent_type\turl\n' > "$OUT/_summary.tsv"
probe telegram          "https://t.me/s/kharkivenergy"
probe github_json       "https://raw.githubusercontent.com/yaroslav2901/OE_OUTAGE_DATA/main/data/Kharkivoblenerho.json"
probe asds1562_home     "https://1562.kharkivrada.gov.ua"
probe oblenergo_gaoinfo "https://www.oblenergo.kharkiv.ua/uk/gaoinfo"
probe oblenergo_home    "https://www.oblenergo.kharkiv.ua/"

# Discover candidate API endpoints / scripts referenced by the 1562 and oblenergo pages.
for n in asds1562_home oblenergo_gaoinfo; do
  grep -oE '(src|href|action)="[^"]+"' "$OUT/$n.body" 2>/dev/null | sort -u > "$OUT/$n.links.txt" || true
  grep -oiE "(fetch|axios[.a-z]*|ajax|XMLHttpRequest|url:)[^;]{0,160}" "$OUT/$n.body" 2>/dev/null | head -50 > "$OUT/$n.js-hints.txt" || true
done
# Telegram: PDF / file hints and older-page cursor
grep -oiE 'data-post="[^"]+"' "$OUT/telegram.body" 2>/dev/null | head -5 > "$OUT/telegram.posts.txt" || true
grep -oiE '(Адрес|Адрес[иі]|черг)[^<]{0,80}' "$OUT/telegram.body" 2>/dev/null | head -20 > "$OUT/telegram.registry-hints.txt" || true
echo "== summary =="; column -t -s$'\t' "$OUT/_summary.tsv"
