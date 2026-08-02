# AGENTS.md

## What this is

SLST — Flutter clients for **Windows**, **Android**, and **Wear OS**, backed by a **hosted Supabase** project. Make.com PM email/SMS is invoked only through the authenticated Edge Function `notify-pm`.

There is **no** web/PWA client and **no** Prophet21 / Epicor integration.

## Local-first development

Development and Flutter packaging builds run on the **local Windows checkout**. Prefer this machine’s `.tools/flutter` bootstrap (or Flutter on PATH), plus local `build/` / `dist/` artifacts. Do not default to Cursor Cloud Agents for app work unless the user asks.

Preferred local folder: this Windows checkout (`Downloads/staging-tracker`). GitHub remote: `StagingLogShippingTracker/staging-tracker`. Product brand is **SLST**.

## Dev commands (local)

```bash
# Prefer repo-local SDK when present:
#   .tools\flutter\bin\flutter.bat   (Windows)
flutter pub get
flutter run -d windows
flutter run -d android
flutter -C apps/slst_wear run -d <wear-device>
flutter test
flutter analyze
```

Do **not** ADB wireless-install phone/Wear after packaging — use in-app **Settings → Update** (GitHub Releases). Only use ADB when the user explicitly asks.

## After app changes — always rebuild (local)

When agents change a Flutter client, they must rebuild the affected platform(s) **locally** before finishing — do not ask the user to rebuild.

- Windows: prefer `scripts/packaging/build-windows-installer.ps1` (and related Windows packaging under `scripts/packaging/`) for distributables.
- Android: `scripts/packaging/build-android-apk.ps1`
- Wear: `scripts/packaging/build-wear-apk.ps1`

Then publish GitHub `releases/latest` with `SLST-*` assets so clients can self-update.
## Live production backend — be careful

- `lib/core/app_config.dart` (and `packages/slst_shared`) points at the **live** Supabase project.
- Authenticated create/edit/ship/delete/notify writes affect real data and can trigger real PM email/SMS via Make.
- Prefer read-only exploration unless you have explicit approval and a confirmed test account.
- Authenticated clients read/write staging/shipped data; RLS blocks anonymous
  SELECT and all writes. Sign in is required to see operational inventory.

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
