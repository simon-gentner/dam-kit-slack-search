#!/usr/bin/env bash
# Offline check of an answer: check-answer.sh <answer.txt>
# Reports format and source defects. Exit 0 = clean, 1 = defects.
# Works for answers in English or German (section headings in both languages).
f="${1:?usage: check-answer.sh <answer.txt>}"
[ -r "$f" ] || { echo "ERROR: cannot read $f"; exit 1; }
bad=0
set -f   # [1] and [P1] are glob patterns: never expand them against files in the current directory
err() { echo "ERROR: $*"; bad=1; }

# Required sections (heading in the answer language)
for h in 'Sources|Quellen' 'Uncertain|Unsicher' 'Searched|Gesucht'; do
  grep -qE "^(\*\*|## )($h)" "$f" || err "missing section: $h"
done

# The first non-empty line must be the bold one-sentence answer: no preamble
first="$(grep -m1 -v '^[[:space:]]*$' "$f")"
case "$first" in
  '**'*) ;;
  *) err "answer does not start with the bold one-sentence answer (preamble or interim comment)";;
esac

# Permalinks: timestamp is p + exactly 16 digits, no dot
while read -r u; do
  ts="${u##*/p}"
  while [[ "$ts" == *. ]]; do ts="${ts%.}"; done   # a sentence-final full stop is not part of the link
  [[ "$ts" =~ ^[0-9]{16}$ ]] || err "altered permalink: $u"
done < <(grep -oE 'https://[a-zA-Z0-9.-]*slack\.com/archives/[A-Z0-9]+/p[0-9.]+' "$f" | sort -u)

# Every cited [n] / [Pn] needs a source entry at the start of a line
for id in $(grep -oE '\[P?[0-9]+\]' "$f" | sort -u); do
  grep -qE "^\\${id%]}\\]" "$f" || err "reference ${id} has no source entry"
done

# Direct-message citations [Pn] need their own section (never mixed into Channels)
if grep -qE '\[P[0-9]+\]' "$f"; then
  grep -qE '^(\*\*|## )(Direct messages|Persönliche Nachrichten)' "$f" \
    || err "[Pn] cited but there is no Direct messages / Persönliche Nachrichten section"
fi

# Source entries that are never cited in the text (hint only)
for id in $(grep -oE '^\[P?[0-9]+\]' "$f" | sort -u); do
  [ "$(grep -oF "$id" "$f" | wc -l)" -ge 2 ] || echo "HINT: ${id} is listed but never cited (ok only as context)"
done

# Images and foreign links
grep -qE '!\[[^]]*\]\(' "$f" && err "embedded image in the answer"
foreign="$(grep -oE 'https?://[^ )>]+' "$f" | grep -vE '^https?://[a-zA-Z0-9.-]*\.slack\.com(/|$)' | head -3)"
[ -n "$foreign" ] && { echo "$foreign" | sed 's/^/ERROR: foreign URL: /'; bad=1; }

# Doubled full stop after a source bracket
grep -nE '\]\)?\.\.' "$f" | head -3 | sed 's/^/HINT: doubled full stop: /'
exit $bad
