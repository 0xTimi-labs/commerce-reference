#!/bin/sh
set -eu

failures=0
fail() {
  printf 'CI required failure: %s\n' "$1" >&2
  failures=$((failures + 1))
}

[ "${CI_PLANNER_RESULT:-}" = success ] || fail "planner result is '${CI_PLANNER_RESULT:-}', expected success"
[ "${CI_CONTRACT_RESULT:-}" = success ] || fail "contract result is '${CI_CONTRACT_RESULT:-}', expected success"
[ -n "${CI_PLANNER_MODE:-}" ] && [ "${CI_PLANNER_MODE:-}" = "${CI_EXPECTED_MODE:-}" ] || \
  fail "planner mode '${CI_PLANNER_MODE:-}' does not match '${CI_EXPECTED_MODE:-}'"
case "${CI_PLAN_JSON:-}" in
  '{"version":1,'*) ;;
  *) fail 'planner did not publish a machine-readable plan' ;;
esac

check_leaf() {
  name=$1
  planned=$2
  result=$3
  case "$planned" in
    true)
      [ "$result" = success ] || fail "$name was planned but result is '$result'"
      ;;
    false)
      [ "$result" = skipped ] || fail "$name was not planned but result is '$result'"
      ;;
    *)
      fail "$name has invalid planner value '$planned'"
      ;;
  esac
}

check_leaf rust "${CI_RUST_PLANNED:-}" "${CI_RUST_RESULT:-}"
check_leaf node "${CI_NODE_PLANNED:-}" "${CI_NODE_RESULT:-}"

[ "$failures" -eq 0 ] || exit 1
printf '%s\n' 'CI required contract passed: every planned job succeeded and every unplanned job was skipped.'
