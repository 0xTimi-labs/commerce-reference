#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
run_required() {
  env \
    CI_PLANNER_RESULT=success \
    CI_CONTRACT_RESULT=success \
    CI_PLANNER_MODE=quick \
    CI_EXPECTED_MODE=quick \
    'CI_PLAN_JSON={"version":1,"mode":"quick"}' \
    "$@" \
    sh "$root/ci/required.sh"
}

run_required \
  CI_RUST_PLANNED=false CI_RUST_RESULT=skipped \
  CI_NODE_PLANNED=false CI_NODE_RESULT=skipped >/dev/null

if run_required \
  CI_RUST_PLANNED=true CI_RUST_RESULT=skipped \
  CI_NODE_PLANNED=false CI_NODE_RESULT=skipped >/dev/null 2>&1; then
  printf '%s\n' 'test-required: planned skipped leaf unexpectedly passed' >&2
  exit 1
fi

if run_required \
  CI_RUST_PLANNED=false CI_RUST_RESULT=success \
  CI_NODE_PLANNED=false CI_NODE_RESULT=skipped >/dev/null 2>&1; then
  printf '%s\n' 'test-required: unplanned successful leaf unexpectedly passed' >&2
  exit 1
fi
printf '%s\n' 'test-required: ok'
