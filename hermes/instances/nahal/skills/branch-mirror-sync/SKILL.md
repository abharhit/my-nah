---
name: branch-mirror-sync
description: When syncing a branch to upstream, then force-pushing fork.
version: 1.0.0
author: nahal
license: MIT
metadata:
  hermes:
    tags: [git, fork, branch, force-push]
    related_skills: [github]
---

# Branch mirror sync (local branch == upstream branch, pushed to fork)

## When to Use

The user asks for a local branch to be exactly equal to an upstream repo's branch (including deleting extra files) and the branch pushed to their own fork — force-pushed if the branch exists, created if missing.

## Procedure

1. **Read remotes first.** Run `git remote -v`; never hardcode the fork. Convention: `origin` = the user's own fork, `upstream` = the canonical repo (h-dashboard: asgarimehdi/<repo>, beta branch). Add upstream if missing:
   `git remote add upstream https://github.com/asgarimehdi/<repo>.git && git fetch upstream beta`
2. **Discard local drift.** Checkout/clean modified tracked files, then:
   `git reset --hard upstream/beta && git clean -fdx && git status -sb`
   Confirm HEAD matches `git rev-parse upstream/beta` and status is clean before pushing.
3. **Push with an explicit refspec.** `git push --force origin HEAD:refs/heads/<branch>` — the same command creates the branch on the fork if missing. Never bare `git push`: on this repo the local branch tracks origin/beta, so a bare push lands on the wrong remote branch. (When the branch name and the push head differ in any way, always write the full refspec.)
4. **Verify three-way equality.** `git rev-parse HEAD upstream/beta` and `git ls-remote origin refs/heads/<branch>` must all return the same SHA, and `git status -sb` must be clean.

## Pitfalls

- `git clean -fdx` deletes gitignored-but-needed files too — it removes `.env` plus `vendor/`/`node_modules/`/build caches. Gitignored ≠ disposable. After any clean -fdx, restore `.env` from the repo's env template (h-dashboard: `cp .env.example.pgsql .env`) and tell the user `composer install && npm install` is needed before anything runs.
- `reset --hard` and force-push trigger approval prompts. Batch each into its own single terminal call (one reset+clean batch, one push batch) — a chain mixing both burns a prompt mid-batch.
