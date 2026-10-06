# Choosing what counts as "new" in an issue watch

The dedup mechanism decides whether the watch is correct, silent, or stuck in a
loop. Check these before writing the gate.

## Pick the state marker that your token can actually write

Run `gh api repos/<owner>/<repo> --jq .permissions` first.

| permissions | can write labels? | state marker to use |
|---|---|---|
| `triage:true` or `push:true` | yes | owned label (`reviewed`) — remote, survives restarts |
| `pull:true` only (fork token) | **no — 403** | your own comment on the issue |
| unsure | test it | comment; label stays best-effort |

`gh issue view` and `gh issue comment` need only `pull: true`. `gh issue edit
--add-label` needs `triage`. A watch gated on a label will therefore loop
forever on a pull-only token: the label never lands, the issue never leaves the
queue, and the agent wakes every tick.

## The single predicate

Prefer one rule over per-bucket logic:

> open AND no owned label AND no comment by my login

Buckets like "needs review" / "only needs a label" appear reasonable but create
a permanent backlog the moment labelling is denied — those issues have a comment
and no label forever, so the queue never drains and every tick re-wakes the
agent. If a label is genuinely a required state, the token needs triage; get the
permission rather than encoding a second code path.

## Wake-gate vs monitor

`monitor` hash-suppresses an unchanged tick; `script` runs a full jq/gh pipeline
and returns a deterministic list. For issue selection use `script` — you need
the list in the prompt, not just a change signal. A `no_agent` job cannot
select, only forward stdout.

The gate must print `{"wakeAgent": false}` as the LAST non-empty line when
there is nothing to do. That is the only shape the scheduler recognizes.

## Testing a gate before trusting it

1. Run the script directly: a real new issue must print the list; the
   all-reviewed state must print the JSON gate.
2. Assert the filter against synthetic fixtures — brand-new, commented, labeled,
   ready-labeled, unrelated-label-only, third-party-comment-only, mixed batch.
   Extract the jq program from the shipped script and run it, so the test cannot
   drift from the real filter.
3. Fire `cronjob(action="run")` once and confirm the run landed where the gate
   predicted.

A gate bug is silent: it either floods the chat with the whole backlog or never
wakes at all, and neither shows up as an error.