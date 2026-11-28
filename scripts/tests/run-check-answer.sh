#!/usr/bin/env bash
# Runs check-answer.sh over the fixtures: ok-* must pass (exit 0), bad-* must fail (exit 1).
D="$(cd "$(dirname "$0")" && pwd)"
CHECK="$D/../check-answer.sh"
fail=0
for f in "$D"/fixtures/*.txt; do
  name="$(basename "$f" .txt)"
  bash "$CHECK" "$f" >/dev/null 2>&1; rc=$?
  case "$name" in
    ok-*)  [ "$rc" -eq 0 ] && echo "OK    $name" || { echo "FAIL  $name (expected pass, exit $rc)"; fail=1; };;
    bad-*) [ "$rc" -eq 1 ] && echo "OK    $name" || { echo "FAIL  $name (expected defect, exit $rc)"; fail=1; };;
  esac
done
exit $fail
