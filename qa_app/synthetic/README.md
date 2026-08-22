# Whole-app improve / training loop

Executable scaffolding for **harness → score → fix → re-run** across shared
domain helpers (validation, subjects, audit order, container KPI smoke).

Same training contract as notify / location / ops — see
`.cursor/rules/improve-loops-training.mdc` and `app-improve-loop.mdc`.

## Layout

```
qa_app/synthetic/
  README.md
  harness_results.json
  improve_log.jsonl
  improve_summary_latest.json
  training_lessons.json
```

## Commands

```powershell
python scripts/app_improve_loop.py
python scripts/app_improve_loop.py --skip-harness
python scripts/improve_loop_training.py append-lesson app --title "..." --lesson "..."
```

## Continuation

1. Read `improve_summary_latest.json` + `training_lessons.json`
2. Fix real top failures; expand cases for new glitches
3. Re-run; append score-proven lessons
4. Do not wait for the user to re-ask
