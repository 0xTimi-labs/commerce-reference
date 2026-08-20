#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

output=${GITHUB_OUTPUT:--}
root=${CI_ROOT:-.}
mode=${CI_MODE:-quick}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { printf '%s\n' 'plan: --output needs a path' >&2; exit 2; }
      output=$2
      shift 2
      ;;
    --root)
      [ "$#" -ge 2 ] || { printf '%s\n' 'plan: --root needs a path' >&2; exit 2; }
      root=$2
      shift 2
      ;;
    --mode)
      [ "$#" -ge 2 ] || { printf '%s\n' 'plan: --mode needs quick or full' >&2; exit 2; }
      mode=$2
      shift 2
      ;;
    *)
      printf 'plan: unexpected argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

case "$mode" in
  quick|full) ;;
  *) printf 'plan: invalid mode: %s\n' "$mode" >&2; exit 2 ;;
esac

root_abs=$(CDPATH='' cd -- "$root" && pwd)
files=$(mktemp "${TMPDIR:-/tmp}/commerce-reference-plan.XXXXXX")
trap 'rm -f "$files"' EXIT HUP INT TERM
(
  cd "$root_abs"
  find . -type f -not -path './.git/*' -print | sed 's#^\./##' | sort
) > "$files"

has_rust=false
has_node=false
rust_count=0
node_count=0
rust_evidence=none
node_evidence=none

while IFS= read -r file; do
  case "$file" in
    Cargo.toml|Cargo.lock|rust-toolchain.toml|*/Cargo.toml|*/Cargo.lock|*/rust-toolchain.toml|*.rs)
      has_rust=true
      rust_count=$((rust_count + 1))
      [ "$rust_evidence" = none ] && rust_evidence=$file
      ;;
    package.json|package-lock.json|.node-version|*/package.json|*/package-lock.json|*/.node-version|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx)
      has_node=true
      node_count=$((node_count + 1))
      [ "$node_evidence" = none ] && node_evidence=$file
      ;;
  esac
done < "$files"

has_ci_workflow=false
has_review_workflow=false
has_review_skill=false
has_ci_scripts=false
[ -f "$root_abs/.github/workflows/ci.yml" ] && has_ci_workflow=true
[ -f "$root_abs/.github/workflows/ai-review.yml" ] && has_review_workflow=true
[ -f "$root_abs/.agents/skills/code-reviewer/SKILL.md" ] && has_review_skill=true
[ -f "$root_abs/ci/verify.sh" ] && [ -f "$root_abs/ci/required.sh" ] && has_ci_scripts=true

plan_json=$(printf '{"version":1,"mode":"%s","has_rust":%s,"has_node":%s,"has_ci_workflow":%s,"has_review_workflow":%s,"has_review_skill":%s,"has_ci_scripts":%s}' \
  "$mode" "$has_rust" "$has_node" "$has_ci_workflow" "$has_review_workflow" "$has_review_skill" "$has_ci_scripts")

[ "$output" = - ] || : > "$output"
emit() {
  if [ "$output" = - ]; then
    printf '%s\n' "$1"
  else
    printf '%s\n' "$1" >> "$output"
  fi
}

emit 'plan_version=1'
emit "mode=$mode"
emit "has_rust=$has_rust"
emit "has_node=$has_node"
emit "has_ci_workflow=$has_ci_workflow"
emit "has_review_workflow=$has_review_workflow"
emit "has_review_skill=$has_review_skill"
emit "has_ci_scripts=$has_ci_scripts"
emit "evidence_rust_count=$rust_count"
emit "evidence_node_count=$node_count"
emit "plan_json=$plan_json"

printf 'CI plan: mode=%s\n' "$mode"
printf 'evidence_rust=%s (count=%s)\n' "$rust_evidence" "$rust_count"
printf 'evidence_node=%s (count=%s)\n' "$node_evidence" "$node_count"
printf 'contract: ci_workflow=%s review_workflow=%s review_skill=%s ci_scripts=%s\n' \
  "$has_ci_workflow" "$has_review_workflow" "$has_review_skill" "$has_ci_scripts"
