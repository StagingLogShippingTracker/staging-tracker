# AGENTS.md

## What this is

SLST — Staging Log & Shipping Tracker: a **Flutter** app (Windows + Android) backed by a **hosted Supabase** project. Make.com PM email/SMS is invoked only through the authenticated Edge Function `notify-pm`.

There is **no** web/PWA client and **no** Prophet21 / Epicor integration.

## Dev commands

```powershell
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat run -d windows
.\.tools\flutter\bin\flutter.bat test
.\.tools\flutter\bin\flutter.bat analyze
```

`.tools/` is gitignored. Document PATH/SDK setup in README if developers use a system Flutter install instead.

## Live production backend — be careful

- `lib/core/app_config.dart` points at the **live** Supabase project.
- Authenticated create/edit/ship/delete/notify writes affect real data and can trigger real PM email/SMS via Make.
- Prefer read-only exploration unless you have explicit approval and a confirmed test account.
- Anonymous clients can still **read** staging/shipped data; RLS blocks anonymous writes.

## Auth

- Email/password via Supabase Auth.
- New accounts require email confirmation (`email_not_confirmed` until confirmed).
- UI gates write actions on `currentUser`; RLS is the real enforcement.

## Layout

- `lib/features/` — screens (dashboard, staging, shipping, reports, notifications, contacts, auth, shell)
- `lib/domain/` — models + status/container rules
- `lib/data/` — repositories, Riverpod app state, operations service
- `lib/platform/` — camera/file picker adapters
- `lib/core/` — config, theme, router
- `supabase/functions/notify-pm` — authenticated Make webhook proxy + PM SMS roster
- `supabase/migrations/` — RLS + private secrets support
- `scripts/packaging/` — portable ZIP / Inno Setup / APK helpers

## Notifications

Never put `MAKE_EMAIL_WEBHOOK_URL` or PM phone gateways in the Flutter client.
Rotate the Make webhook via Edge secret or `private.app_secrets`.

## Packaging

See README for portable Windows ZIP, per-user Inno installer, and APK scripts.
Signing secrets (`android/key.properties`, `*.jks`, `*.keystore`) must stay out of git.
