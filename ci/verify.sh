#!/bin/sh
set -eu

mode=${1:-quick}
case "$mode" in quick|full) ;; *) printf 'verify: invalid mode: %s\n' "$mode" >&2; exit 2 ;; esac
root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
fail() { printf 'verify: %s\n' "$1" >&2; exit 1; }

for required in \
  README.md LICENSE .gitignore .github/CODEOWNERS \
  .github/workflows/ci.yml .github/workflows/ai-review.yml \
  .agents/skills/code-reviewer/SKILL.md .pi/models.example.json \
  ci/plan.sh ci/required.sh ci/run-stack.sh ci/review/validate-output.sh; do
  [ -f "$root/$required" ] || fail "missing required file: $required"
done

for script in "$root"/ci/*.sh "$root"/ci/review/*.sh "$root"/ci/tests/*.sh; do
  [ -f "$script" ] || continue
  sh -n "$script" || fail "shell syntax failed: $script"
done

uses_file=$(mktemp "${TMPDIR:-/tmp}/commerce-reference-uses.XXXXXX")
trap 'rm -f "$uses_file"' EXIT HUP INT TERM
grep -hE '^[[:space:]]*uses:' "$root"/.github/workflows/*.yml > "$uses_file" || true
while IFS= read -r line; do
  printf '%s\n' "$line" | grep -Eq '@[0-9a-f]{40}([[:space:]]|$)' || \
    fail "workflow action is not pinned to a full SHA: $line"
done < "$uses_file"

if grep -R -n 'pull_request_target' "$root/.github/workflows" >/dev/null 2>&1; then
  fail 'pull_request_target is forbidden'
fi

grep -q 'pull_request:' "$root/.github/workflows/ci.yml" || fail 'CI pull_request trigger missing'
grep -q 'merge_group:' "$root/.github/workflows/ci.yml" || fail 'CI merge_group trigger missing'
grep -q 'checks_requested' "$root/.github/workflows/ci.yml" || fail 'CI merge_group trigger type missing'
grep -q 'workflow_dispatch:' "$root/.github/workflows/ci.yml" || fail 'CI workflow_dispatch trigger missing'
grep -q 'always()' "$root/.github/workflows/ci.yml" || fail 'CI required job must use always()'

grep -q -- '@earendil-works/pi-coding-agent@0.84.2' "$root/.github/workflows/ai-review.yml" || fail 'Pi version is not pinned'
grep -q -- '--no-tools' "$root/.github/workflows/ai-review.yml" || fail 'Pi must run without filesystem or execution tools'
if grep -q -- '--tools' "$root/.github/workflows/ai-review.yml"; then
  fail 'AI review must not enable built-in tools'
fi
if grep -q 'actions: write' "$root/.github/workflows/ai-review.yml"; then
  fail 'AI review has unnecessary Actions write permission'
fi
base_sha_literal="\$BASE_SHA"
trusted_validator_literal="\$TRUSTED_VALIDATOR"
trusted_skill_literal="\$TRUSTED_SKILL"
grep -Fq "git show \"$base_sha_literal:.agents/skills/code-reviewer/SKILL.md\"" "$root/.github/workflows/ai-review.yml" || fail 'review skill is not loaded from protected base'
grep -Fq "git show \"$base_sha_literal:.pi/models.example.json\"" "$root/.github/workflows/ai-review.yml" || fail 'model config is not loaded from protected base'
grep -Fq "git show \"$base_sha_literal:ci/review/validate-output.sh\"" "$root/.github/workflows/ai-review.yml" || fail 'result validator is not loaded from protected base'
grep -Fq "sh \"$trusted_validator_literal\"" "$root/.github/workflows/ai-review.yml" || fail 'trusted result validator is not executed'
grep -Fq -- "--append-system-prompt \"$trusted_skill_literal\"" "$root/.github/workflows/ai-review.yml" || fail 'trusted review skill is not injected into the system prompt'
grep -q 'timeout-minutes: 60' "$root/.github/workflows/ai-review.yml" || fail 'AI Review timeout is not 60 minutes'
grep -q 'REVIEWED_SHA' "$root/.agents/skills/code-reviewer/SKILL.md" || fail 'review skill terminal SHA is missing'

node -e '
  const p=require(process.argv[1]);
  const d=p.providers?.deepseek;
  const m=d?.models?.[0];
  if (d?.baseUrl!=="https://api.deepseek.com/v1" || d?.api!=="openai-completions" || d?.apiKey!==process.argv[2] || d?.models?.length!==1 || m?.id!=="deepseek-v4-flash") process.exit(1);
' "$root/.pi/models.example.json" "\$DEEPSEEK_API_KEY" || fail 'DeepSeek model contract is invalid'

if command -v actionlint >/dev/null 2>&1; then
  actionlint -color=false "$root/.github/workflows/ci.yml" "$root/.github/workflows/ai-review.yml"
elif command -v go >/dev/null 2>&1; then
  GOTOOLCHAIN=local GOPROXY=https://proxy.golang.org go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 \
    -color=false "$root/.github/workflows/ci.yml" "$root/.github/workflows/ai-review.yml"
elif [ "${CI_REQUIRE_ACTIONLINT:-false}" = true ]; then
  fail 'actionlint or Go is required in CI'
else
  printf '%s\n' 'verify: actionlint unavailable; static workflow checks continue'
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$root"/ci/*.sh "$root"/ci/review/*.sh "$root"/ci/tests/*.sh
fi

sh "$root/ci/tests/test-plan.sh"
sh "$root/ci/tests/test-required.sh"
sh "$root/ci/tests/test-review-output.sh"
printf 'verify: %s passed\n' "$mode"
