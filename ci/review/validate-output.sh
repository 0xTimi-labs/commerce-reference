#!/bin/sh
set -eu

report=${1:-}
expected_sha=${2:-}
pi_outcome=${3:-}
cache_restore_outcome=${4:-}
cache_save_outcome=${5:-}
key_outcome=${6:-}
context_outcome=${7:-}
install_outcome=${8:-}

fail() {
  printf 'AI review validation failure: %s\n' "$1" >&2
  exit 1
}

[ "$pi_outcome" = success ] || fail "Pi step result is '$pi_outcome'"
[ "$cache_restore_outcome" = success ] || fail "session cache restore result is '$cache_restore_outcome'"
[ "$cache_save_outcome" = success ] || fail "session cache save result is '$cache_save_outcome'"
[ "$key_outcome" = success ] || fail "DeepSeek key check result is '$key_outcome'"
[ "$context_outcome" = success ] || fail "review context result is '$context_outcome'"
[ "$install_outcome" = success ] || fail "Pi installation/configuration result is '$install_outcome'"
if [ -z "$report" ] || [ ! -f "$report" ]; then
  fail 'review output file is missing'
fi
[ -s "$report" ] || fail 'review output is empty'

[ "${#expected_sha}" -eq 40 ] || fail 'expected SHA is not 40 characters'
case "$expected_sha" in
  *[!0-9a-f]*) fail 'expected SHA is not lowercase hexadecimal' ;;
esac

nonblank=$(mktemp "${TMPDIR:-/tmp}/commerce-reference-review.XXXXXX")
trap 'rm -f "$nonblank"' EXIT HUP INT TERM
sed '/^[[:space:]]*$/d' "$report" >"$nonblank"
line_count=$(wc -l <"$nonblank" | tr -d '[:space:]')
[ "$line_count" -ge 4 ] || fail 'review output has no complete terminal record'

result_count=$(grep -c '^REVIEW_RESULT: ' "$report" || true)
sha_count=$(grep -c '^REVIEWED_SHA: ' "$report" || true)
blocker_count=$(grep -c '^BLOCKERS: ' "$report" || true)
end_count=$(grep -c '^END_REVIEW$' "$report" || true)
[ "$result_count" -eq 1 ] || fail 'REVIEW_RESULT must occur exactly once'
[ "$sha_count" -eq 1 ] || fail 'REVIEWED_SHA must occur exactly once'
[ "$blocker_count" -eq 1 ] || fail 'BLOCKERS must occur exactly once'
[ "$end_count" -eq 1 ] || fail 'END_REVIEW must occur exactly once'

last_four=$(tail -n 4 "$nonblank")
expected_terminal=$(printf '%s\n%s\n%s\n%s' \
  'REVIEW_RESULT: PASS' \
  "REVIEWED_SHA: $expected_sha" \
  'BLOCKERS: 0' \
  'END_REVIEW')
if [ "$last_four" = "$expected_terminal" ]; then
  printf '%s\n' 'AI review terminal record: PASS'
  exit 0
fi

result=$(sed -n 's/^REVIEW_RESULT: //p' "$report")
reviewed_sha=$(sed -n 's/^REVIEWED_SHA: //p' "$report")
blockers=$(sed -n 's/^BLOCKERS: //p' "$report")
[ "$reviewed_sha" = "$expected_sha" ] || fail 'reviewed SHA does not match the checked-out SHA'
case "$result" in PASS|BLOCK) ;; *) fail "invalid review result '$result'" ;; esac
case "$blockers" in ''|*[!0-9]*) fail 'BLOCKERS is not a non-negative integer' ;; esac
[ "$result" = BLOCK ] || fail 'PASS terminal record is malformed'
[ "$blockers" -gt 0 ] || fail 'BLOCK result must contain a positive blocker count'
fail 'review reported blocker(s)'
