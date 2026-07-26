# AGENTS.md

## What this is

SLST — Staging Log & Shipping Tracker: **Flutter clients** for **Windows**, **Android**, and **Wear OS**, backed by a **hosted Supabase** project. Make.com PM email/SMS is invoked only through the authenticated Edge Function `notify-pm`.

There is **no** web/PWA client and **no** Prophet21 / Epicor integration.

## Cloud-first development

Future development and Flutter packaging builds run in **Cursor Cloud Agents**. Do not assume a local Windows checkout, local `.tools/` Flutter SDK, or local `dist/` / `build/` artifacts.

## Dev commands (cloud agent)

Prefer a system Flutter on PATH in the cloud environment (or whatever the cloud image provides):

```bash
flutter pub get
flutter run -d windows   # when a Windows target is available
flutter run -d android
flutter -C apps/slst_wear run -d <wear-device>
flutter test
flutter analyze
```

Legacy local note: `.tools/` was a gitignored Windows SDK bootstrap and is not required for cloud work.

## After app changes — always rebuild (in cloud)

When agents change a Flutter client, they must rebuild the affected platform(s) in the **cloud** environment before finishing — do not ask the user to rebuild locally.

- Windows: prefer `scripts/packaging/build-windows-installer.ps1` (and related Windows packaging under `scripts/packaging/`) for distributables.
- Android: `scripts/packaging/build-android-apk.ps1`
- Wear: `scripts/packaging/build-wear-apk.ps1`

## Live production backend — be careful

- `lib/core/app_config.dart` (and `packages/slst_shared`) points at the **live** Supabase project.
- Authenticated create/edit/ship/delete/notify writes affect real data and can trigger real PM email/SMS via Make.
- Prefer read-only exploration unless you have explicit approval and a confirmed test account.
- Anonymous clients can still **read** staging/shipped data; RLS blocks anonymous writes.

## Auth

- Email/password via Supabase Auth (Windows / Android).
- Wear pairs via Settings → **Pair Watch** → `watch-pair` Edge Function redeem.
- New accounts require email confirmation (`email_not_confirmed` until confirmed).
- UI gates write actions on `currentUser`; RLS is the real enforcement.

## Layout

- `lib/features/` — screens (dashboard, staging, shipping, reports, notifications, contacts, auth, shell, settings)
- `lib/domain/` — models + status/container rules
- `lib/data/` — repositories, Riverpod app state, operations service
- `lib/platform/` — camera/file picker adapters
- `lib/core/` — config, theme, router
- `packages/slst_shared/` — shared domain/data used by Windows, Android, and Wear
- `apps/slst_wear/` — Wear OS Flutter client (pair, list, ship, lean SVR)
- `android/` — Android host for the main phone/tablet client
- `windows/` — Windows desktop host
- `supabase/functions/notify-pm` — authenticated Make webhook proxy + PM SMS roster
- `supabase/functions/watch-pair` — Wear pairing create/redeem
- `supabase/migrations/` — RLS + private secrets support
- `scripts/packaging/` — Windows ZIP / Inno, Android APK, Wear APK helpers

## Notifications

Never put `MAKE_EMAIL_WEBHOOK_URL` or PM phone gateways in the Flutter client.
Rotate the Make webhook via Edge secret or `private.app_secrets`.

## Packaging

See README for portable Windows ZIP, per-user Inno installer, Android APK, and Wear APK.
