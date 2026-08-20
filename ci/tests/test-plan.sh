#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/commerce-reference-plan-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/empty" "$tmp/stacks"
: > "$tmp/stacks/Cargo.toml"
: > "$tmp/stacks/package.json"

full_output=$tmp/full.out
CI_ROOT="$tmp/stacks" CI_MODE=full sh "$root/ci/plan.sh" \
  --output "$full_output" --root "$tmp/stacks" --mode full >/dev/null
grep -Fx 'mode=full' "$full_output" >/dev/null
grep -Fx 'has_rust=true' "$full_output" >/dev/null
grep -Fx 'has_node=true' "$full_output" >/dev/null
grep -Fx 'evidence_rust_count=1' "$full_output" >/dev/null
grep -Fx 'evidence_node_count=1' "$full_output" >/dev/null

empty_output=$tmp/empty.out
sh "$root/ci/plan.sh" --output "$empty_output" --root "$tmp/empty" --mode quick >/dev/null
grep -Fx 'mode=quick' "$empty_output" >/dev/null
grep -Fx 'has_rust=false' "$empty_output" >/dev/null
grep -Fx 'has_node=false' "$empty_output" >/dev/null

if sh "$root/ci/plan.sh" --root "$tmp/empty" --mode invalid >/dev/null 2>&1; then
  printf '%s\n' 'test-plan: invalid mode unexpectedly passed' >&2
  exit 1
fi
printf '%s\n' 'test-plan: ok'
