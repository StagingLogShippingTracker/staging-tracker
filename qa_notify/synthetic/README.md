# Notify / email improve / training loop

Harness for **all PM notification payload contracts** (ship, quick ship,
return-to-stock, PO, bulk PO, return, feedback) before Make delivery.

See `.cursor/rules/improve-loops-training.mdc` and `notify-improve-loop.mdc`.

## Commands

```powershell
python scripts/notify_improve_loop.py
python scripts/improve_loop_training.py append-lesson notify --title "..." --lesson "..."
```

## Constraints

- Never embed `MAKE_EMAIL_WEBHOOK_URL` in Flutter
- Keep Make scenario active when fixing delivery
- Every payload needs valid `to` + `cc` (Outlook rejects empty CC)
