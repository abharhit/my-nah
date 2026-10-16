---
name: docs-restructure
description: "Use when a repo doc is too big or cluttered. Split it."
version: 1.0.0
author: Nahal (Hermes Agent)
license: MIT
metadata:
  hermes:
    tags: [docs, restructure, agents-md, splitting, docs-housekeeping]
    category: note-taking
    related_skills: [github, codebase-inspection]
---

# Docs restructure (fat instruction file → lean core + topic files)

## When to Use

Use when the task is "this file is too big / cluttered" about a repo instruction or doc file
(AGENTS.md, CLAUDE.md, README, docs/*). Deliverable: a fast-scan core every session can read,
plus topic files that carry each fact exactly once.

## Gates (before touching the file)

0. **Check upstream drift first.** `git diff <merge-base>..upstream -- <file>` before planning the
   split; doc-fix commits upstream after your branch point shift line ranges and stale out any
   content you move — port each delta instead of moving a stale copy. Split from upstream's
   current version, or budget an explicit port step for every delta.
1. **Measure first, propose second.** Run `scripts/section-weight.py <file>`; bring the
   byte/line weight per section to the user plus the proposed keep-criterion and your calls
   marked as your calls. Get an explicit go before editing — these files are the project's
   agent instructions and the owner owns their shape.
2. **Find who defers to the file.** `search_files` (pattern=`<filename>`, target=content, or
   files mode by name) for READMEs, ADRs, tests, scripts that cite it — some cite it by
   the rules themselves; moved files hold detail/evidence only.
3. **Protected-file rule.** If the file is flagged protected or the user wants per-change
   approval: build the full replacement in a temp file, present it, then copy into the
   original in ONE approved operation. **Never bypass a write gate with a shell copy** — the
   gate is the user's approval step, not a technical limit. If a change already landed
   without consent, restore the original immediately and re-request; less damage to undo.
4. **Reference policy for checked-in docs.** Point every repo/documentation reference at the
   canonical upstream URL only; never name fork accounts. Per-clone origin/branch is read at
   runtime (`git remote -v` / `git branch --show-current`), never hardcoded.

## Steps

1. **Quantify duplication.** When a rule appears both as prose and again in a quick-reference
   table, the prose wins and the row is dropped — same lesson twice is one rule. Top-of-file
   changelog/doc-review blocks are history, not guidance: drop them.
2. **Extract verbatim by line range with a script — never retype.** One file per topic in the
   existing docs dir (e.g. `docs/agents/<topic>.md`); transplanted table rows go under a
   single `## Gotchas` appendix table per file. Retyped content drifts; verbatim moves don't.
   Build the file list from the UNION of section buckets and row-only buckets — iterating
   sections alone silently skips topics whose entire content lives in quick-reference rows
   (a core rule links to a file that never got written).
   Make every file write idempotent (skip if the target text/`## Gotchas` block is already
   present) — verification crashes and reruns must not double-append.
3. **Account for every byte, grep-mechanically.** The "dropped as dup" claim is only true if
   the carrying section survived VERBATIM — if you also rewrote/condensed that section while
   building the core, the dropped row is an omission, not a duplicate. For every dropped row
   pick a grep token from its real carrier (core or topic file) and assert it exists; for
   every moved row, assert its exact first cell landed in the target file. Keep the
   row-by-row mapping table (row → moved-to / duplicate-of, each verdict grep-provable) and
   publish it as a PR comment before requesting review — reviewers run their own sweep and
   demand this mapping; hand it to them instead of waiting for the complaint.
4. **Hand-write the core:**
   - one-line hard rules, each linking its topic file; commands; debugging order; a map table
     ("where the detail lives"); the size cap stated in the file's own header (e.g. "under
     200 lines / 18 KB") so future growth gets refused by the doc itself.
   - no issue numbers, dates, or changelog in the core; those stay with the detail.
   - state the canonical URL + fork rule in the header if the repo is forked.
5. **Stage provenance.** Each topic file gets a one-line header: split out of `<file>` on
   `<date>`; that file keeps one-liners, this file keeps detail.
6. **Cross-reference sweep.** Fix every caller that names a moved section — tests citing
   line numbers, install guides, ADRs, session-rule files. Then verify: end size wc, no
   dropped-account gap, all links resolve, no fork names left.
7. **Commit + draft PR** when the user wants to review; into canonical `beta` with an
   explicit fork refspec (`HEAD:refs/heads/<branch>`), not a guessed one. Create the PR with
   the `gh` CLI from the fork clone — long RTL/unicode PR bodies keep choking structured
   PR-creation tool calls: `gh pr create --repo <canonical-owner>/<repo> --base <upstream-base>
   --head <fork-owner>:<branch> --draft --title ... --body ...`.
8. **Rebase drift after an upstream doc-fix lands.** Port every upstream delta into the split
   corpus (core gets the one-line version, topic files get the verbatim version) BEFORE the
   rebase; then resolve the protected file's conflict with "ours" — reverting "theirs" onto
   the hand-ported corpus loses the port. Read review verdicts from
   `gh api repos/<owner>/<repo>/pulls/<n>/reviews` (issue comments are empty for reviews).

## Pitfalls

- Over the stated cap? Say so and ask to trim or raise — never silently relax it.
- If the user hands a rule about content (e.g. URL policy), apply it repo-wide to the files
  in scope during the same pass, and say where you applied it.
- Draft PRs let the user review without blocking others; only un-draft on their say-so (this repo's CI runs on drafts to). Three blocking checks here: `lint`, `test`, `phpstan`; `coverage-report`/`e2e`/`mutation`/`test-php86` are `continue-on-error`.
- A reviewer's verdict lives in `pulls/<n>/reviews`, not issue comments; their "sweep found 48 missing cells" is usually (a) content漂 from post-branch-point upstream fixes and (b) actual omissions — verify each claim mechanically before crediting it.
- Long Persian/RTL text written straight into tool calls can come out wrong — re-read any PR comment/body right after posting (via the API, not your draft) and patch it if garbled; two of this session's PR comments shipped mangled sentences and needed EDIT calls.
- A reviewer's "N cells missing" is usually (a) upstream doc-fix commits after your branch point and/or (b) real omissions from your own rewrite — verify each claim mechanically before crediting it.
- Un-drafting: check `isDraft` via the API instead of assuming; `gh pr ready` silently succeeds even when the PR is already undrafted.