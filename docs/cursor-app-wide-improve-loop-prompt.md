# Cursor prompt — App-wide improve loop (portable)

Copy this into a project rule (`.cursor/rules/improve-loops-training.mdc` with
`alwaysApply: true`) or into **Cursor Settings → Rules → User Rules**. Adapt
domain names and paths to the repo.

---

## Prompt (paste)

```markdown
# App-wide improve loops = continuous training (always)

You own this product’s improve-loop curriculum. Do not wait to be asked to run it.
Treat every domain as ongoing training: score → fix → re-score → keep lessons → expand cases.

## What “app-wide” means

Cover EVERY design surface, function, operation, and third-party connector:
UI/shell, domain logic, platform clients, auth, updates/packaging, scanners,
reports, theme/brand, contacts/roster, backend/edge, and external automations
(Make, Stripe, email, etc.). Also cover **repo hygiene**: dead, legacy, unused,
fragmented, or dysfunctional files/folders that only waste disk/GitHub storage.

## Domain layout (create these)

| Domain | Path | Runner idea |
|--------|------|-------------|
| core/app | `qa_<domain>/synthetic/` | unit/widget harness → score → summary |
| each major feature | same | same |
| connectors | same | static + live contract checks |
| hygiene | `qa_hygiene/synthetic/` | discover → **auto-delete safe junk** → gitignore harden |

Each domain keeps:
- `harness_results.json` (case_id, ok, duration_ms, gates_raw, metrics_raw)
- `improve_summary_latest.json` (mean_composite, top_failures, next)
- `improve_log.jsonl` (history)
- `training_lessons.json` (durable lessons + run_snapshots)

## Training contract (every session that touches a domain)

1. Read that domain’s `improve_summary_latest.json` first.
2. Attack real top failures (not scorer noise / honest limits).
3. Re-run the domain runner; promote only score-proven changes.
4. Append lessons: what failed, what fixed it, what must never regress.
5. Expand cases when new failure modes appear.
6. If scores plateau, document the honest limit and raise the case matrix.

## Session habit (no prompting required)

- When you touch a domain, run at least one improve-loop iteration before stopping.
- After broad product changes, run the full curriculum (`run_all_improve_loops`).
- Always run **hygiene** periodically and after packaging/agent scratch work.
- Hunt redundancies, broken/dead UI, missing flow-breakers, and cross-domain
  contradictions; lock each real bug into a harness case.

## Hygiene auto-delete policy

Maintain a **safe-delete allowlist** of path patterns (examples):
- `_legacy*`, `legacy-*`, nested full-repo mirrors
- `.tmp-*`, `_mcp_deploy`, agent scratch JSON/logs
- orphaned build logs committed by mistake

Maintain a **protected tree denylist**: `src`/`lib`/`app`/`packages`/`supabase`/
`scripts` (product), `.git`, `.github`, live assets.

On each hygiene run:
1. Discover candidates matching safe patterns only.
2. Delete them from disk (and `git rm` if tracked).
3. Harden `.gitignore` so they cannot return to GitHub.
4. Fail the loop if protected trees are missing or a nested repo mirror remains.
5. Record `last_cleanup.json` (bytes/files freed).

Never ask permission to delete paths on the safe list. Never delete protected trees.

## Scoring

- Per-case composite from success + speed (+ optional integrity/coverage).
- Domain OK when mean_composite ≥ 0.85 and no gate failures.
- Gates fail closed (cap composite) for security/brand/connector contracts.

## Cross-cutting hard rules (customize)

- Secrets never in clients (webhook URLs, service-role keys, API secrets).
- Packaging/update assets must not cross-install wrong platform builds.
- Do not publish releases / force-push / ADB-install unless the user asked.
- Commit only when the user asks (unless a project rule says otherwise).

## Minimal scripts to add

- `scripts/improve_loop_runner.py <domain|all>`
- `scripts/improve_score.py`
- `scripts/improve_loop_training.py` (lessons + snapshots)
- `scripts/run_all_improve_loops.py`
- `scripts/repo_hygiene_improve_harness.py` (discover + delete + gitignore)
- One harness per domain (language of the repo: Dart/TS/Python/…)

## Done means

- Curriculum ran for touched domains
- Failures fixed or documented as honest limits
- New regressions have new cases
- Hygiene left no safe-list junk behind
```

---

## Quick install checklist (other repos)

1. Paste the prompt into `.cursor/rules/improve-loops-training.mdc` (`alwaysApply: true`).
2. Copy the script shapes from this repo’s `scripts/improve_*.py` + `repo_hygiene_improve_harness.py`.
3. Create `qa_<domain>/synthetic/` folders and one harness per domain.
4. Run `python scripts/run_all_improve_loops.py` once to baseline.
5. After the first cleanup, commit `.gitignore` changes (when you ask for a commit).
