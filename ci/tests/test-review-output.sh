#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/commerce-reference-review-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

cat > "$tmp/report" <<EOF
没有 must-fix。
REVIEW_RESULT: PASS
REVIEWED_SHA: $sha
BLOCKERS: 0
END_REVIEW
EOF
sh "$root/ci/review/validate-output.sh" "$tmp/report" "$sha" \
  success success success success success success success >/dev/null

cat > "$tmp/block" <<EOF
MUST-FIX 1 — src/example:1
REVIEW_RESULT: BLOCK
REVIEWED_SHA: $sha
BLOCKERS: 1
END_REVIEW
EOF
if sh "$root/ci/review/validate-output.sh" "$tmp/block" "$sha" \
  success success success success success success success >/dev/null 2>&1; then
  printf '%s\n' 'test-review-output: blocker unexpectedly passed' >&2
  exit 1
fi

if sh "$root/ci/review/validate-output.sh" "$tmp/report" bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  success success success success success success success >/dev/null 2>&1; then
  printf '%s\n' 'test-review-output: SHA mismatch unexpectedly passed' >&2
  exit 1
fi

sed '$d' "$tmp/report" > "$tmp/incomplete"
if sh "$root/ci/review/validate-output.sh" "$tmp/incomplete" "$sha" \
  success success success success success success success >/dev/null 2>&1; then
  printf '%s\n' 'test-review-output: incomplete output unexpectedly passed' >&2
  exit 1
fi
printf '%s\n' 'test-review-output: ok'
