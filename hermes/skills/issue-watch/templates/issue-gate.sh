#!/usr/bin/env bash
# Wake-gate for an issue-watch cron job. Copy to ~/.hermes/scripts/<slug>-gate.sh
# and set as the job's `script`.
#
# Selection: OPEN issues with neither an owned label nor a comment by
# REVIEWER_LOGIN. The comment is the state marker — it lives on the remote and
# works with a pull-only token, which cannot write labels.
#
# Qualifying issues -> print the list, the agent wakes and reviews them.
# Nothing qualifying   -> last stdout line is JSON {"wakeAgent": false}, and the
#                         scheduler skips the agent entirely (no LLM, no delivery).
# A bare `wakeAgent=false` token is NOT recognized — the gate parses the LAST
# non-empty stdout line as JSON.

set -uo pipefail

REPO="${ISSUE_GATE_REPO:-OWNER/REPO}"
REVIEWER_LOGIN="${ISSUE_GATE_LOGIN:-YOUR_GITHUB_LOGIN}"
OWNED_LABELS="${ISSUE_GATE_OWNED_LABELS:-reviewed ready}"

issues_json="$(gh issue list -R "$REPO" --state open --limit 100 \
  --json number,title,createdAt,labels,comments 2>/dev/null)" || {
    # Source failure must NOT look like "nothing new" — that would silently
    # stop the watch. Report loudly so the run surfaces an error.
    echo "ERROR: gh issue list failed for $REPO" >&2
    exit 1
  }

pending="$(printf '%s' "$issues_json" | jq -r \
    --arg login "$REVIEWER_LOGIN" \
    --arg owned "$OWNED_LABELS" '
  ($owned | split(" ")) as $owned
  | [ .[]
      | select(
          ([ .labels[]?.name ] | map(. as $l | $owned | index($l)) | any(. != null)) | not
        )
      | select(([ .comments[]? | select(.author.login == $login) ] | length) == 0)
    ]
  | sort_by(.createdAt)
  | .[] | "#\(.number) | created=\(.createdAt) | \(.title)"
')"

if [ -z "${pending//[[:space:]]/}" ]; then
  printf '{"wakeAgent": false}\n'
  exit 0
fi

cat <<EOF
New issues on $REPO — open, no $REVIEWER_LOGIN comment, and none of these labels: $OWNED_LABELS.
Review EVERY one below, post exactly one expert comment on each, then label it:

$pending

Rules:
- One comment per issue, ever. Re-check \`gh issue view <n> --json comments\` before writing; if a comment from $REVIEWER_LOGIN already exists, drop the issue.
- Add the label with: gh issue edit <n> --repo $REPO --add-label <label>
  A 403 here means the token lacks triage permission. That is expected on a fork token — it is not a failed review, do not retry, and do not change the comment.
EOF