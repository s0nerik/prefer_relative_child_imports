#!/usr/bin/env bash

# Runs dart analyze on example/ and fails if:
# - any line marked // ❌ BAD in example/lib/**/*.dart does not have a matching
#   analyzer warning or error (false negative), or
# - any line marked // ✅ GOOD has a diagnostic on that line (false positive).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root/example"

tmp_expected="$(mktemp)"
tmp_good="$(mktemp)"
tmp_actual="$(mktemp)"
trap 'rm -f "$tmp_expected" "$tmp_good" "$tmp_actual"' EXIT

while IFS= read -r -d '' f; do
  grep -n '❌ BAD' "$f" 2>/dev/null | while IFS=: read -r linenum _; do
    echo "$f:$linenum"
  done || true
done < <(find lib -name '*.dart' -print0) | sort -u >"$tmp_expected"

while IFS= read -r -d '' f; do
  grep -n '✅ GOOD' "$f" 2>/dev/null | while IFS=: read -r linenum _; do
    echo "$f:$linenum"
  done || true
done < <(find lib -name '*.dart' -print0) | sort -u >"$tmp_good"

set +e
analyze_out="$(dart analyze 2>&1)"
set -e

printf '%s\n' "$analyze_out"

while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*(error|warning)[[:space:]]+-[[:space:]]+(lib/[^:]+):([0-9]+):[0-9]+[[:space:]]+- ]] || continue
  echo "${BASH_REMATCH[2]}:${BASH_REMATCH[3]}"
done <<<"$analyze_out" | sort -u >"$tmp_actual"

missing=0
while IFS= read -r pair || [[ -n "${pair:-}" ]]; do
  [[ -z "${pair:-}" ]] && continue
  if ! grep -Fxq "$pair" "$tmp_actual"; then
    printf 'validate_lint.sh: missing dart analyze error for BAD-marked line %s\n' "$pair" >&2
    missing=$((missing + 1))
  fi
done <"$tmp_expected"

if [[ "$missing" -gt 0 ]]; then
  echo "--------------------------------"
  echo "❌ validate_lint.sh: failed (false negatives)"
  exit 1
fi

unexpected=0
while IFS= read -r pair || [[ -n "${pair:-}" ]]; do
  [[ -z "${pair:-}" ]] && continue
  if grep -Fxq "$pair" "$tmp_actual"; then
    printf 'validate_lint.sh: unexpected dart analyze error on GOOD-marked line %s (false positive)\n' "$pair" >&2
    unexpected=$((unexpected + 1))
  fi
done <"$tmp_good"

if [[ "$unexpected" -gt 0 ]]; then
  echo "--------------------------------"
  echo "❌ validate_lint.sh: failed (false positives)"
  exit 1
fi

echo "--------------------------------"
echo "✅ validate_lint.sh: success"
exit 0
