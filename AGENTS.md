# AGENTS.md

## What this is

Swift Staging & Shipping Log — Flutter clients for **Windows**, **Android**, and **Wear OS**, backed by a **hosted Supabase** project. Make.com PM email is invoked only through the Edge Function `notify-pm` (server-side Make proxy; floor clients need no user sign-in).

There is **no** web/PWA client and **no** Prophet21 / Epicor integration.

## Local-first development

Development and Flutter packaging builds run on the **local Windows checkout**. Prefer this machine’s `.tools/flutter` bootstrap (or Flutter on PATH), plus local `build/` / `dist/` artifacts. Do not default to Cursor Cloud Agents for app work unless the user asks.

Preferred local folder: this Windows checkout (`Projects/Swift-Staging-and-Shipping-Log`). GitHub remote: `StagingLogShippingTracker/staging-tracker`. Product brand is **Swift Staging & Shipping Log**. The folder uses hyphens (no `&` or spaces) so Windows Flutter native-asset hooks can build.

## Dev commands (local)

```bash
# Prefer repo-local SDK when present:
#   .tools\flutter\bin\flutter.bat   (Windows)
flutter pub get
flutter run -d windows
flutter run -d android
flutter -C apps/wear run -d <wear-device>
flutter test
flutter analyze
```

Do **not** ADB wireless-install phone/Wear after packaging — use in-app **Settings → Update** (GitHub Releases). Only use ADB when the user explicitly asks.

## After app changes — always rebuild (local)

When agents change a Flutter client, they must rebuild the affected platform(s) **locally** before finishing — do not ask the user to rebuild.

- Windows: prefer `scripts/packaging/build-windows-installer.ps1` (and related Windows packaging under `scripts/packaging/`) for distributables.
- Android: `scripts/packaging/build-android-apk.ps1`
- Wear: `scripts/packaging/build-wear-apk.ps1`

Then publish GitHub `releases/latest` with `SwiftStagingLog-*` assets so clients can self-update.
## Live production backend — be careful

- `lib/core/app_config.dart` (and `packages/swift_staging_shared`) points at the **live** Supabase project.
- Since the `20260815150000_open_anon_app_access.sql` migration (v1.1.43+46), `staging`/`shipped`/`changelog`/`dropdown_roster`/notify/inventory RPCs are open to the Supabase **anon** role — the floor app has no sign-in gate. Create/edit/ship/delete/notify writes still affect real data and can trigger real PM email via Make, with or without a signed-in session.
- Prefer read-only exploration unless you have explicit approval, regardless of auth state.

## Auth

- The floor app (staging, shipping, notifications, reports, contacts) and **Wear pairing** work fully **without signing in** — RLS/anon grants are the only gate, and `OperationsService._requireAuth()` / `InventoryRpc._requireAuth()` are intentional no-ops. Do not reintroduce `currentUser`/`currentSession` checks on those write paths (see `qa_notify/synthetic/training_lessons.json`).
- Settings → **Pair Watch** creates a 6-digit code via `watch-pair` (anon). Wear redeems the code and stays on anon access — no email/password login.
- `lib/features/auth/login_screen.dart` is unused legacy UI (do not wire it back as a floor gate).
- New accounts / email confirmation are irrelevant to floor ops.

## Layout

- `lib/features/` — screens (dashboard, staging, shipping, reports, notifications, contacts, auth, shell, settings)
- `lib/domain/` — models + status/container rules
- `lib/data/` — repositories, Riverpod app state, operations service
- `lib/platform/` — camera/file picker adapters
- `lib/core/` — config, theme, router
- `packages/swift_staging_shared/` — shared domain/data used by Windows, Android, and Wear
- `apps/wear/` — Wear OS Flutter client (pair, list, ship, lean SVR)
- `android/` — Android host for the main phone/tablet client
- `windows/` — Windows desktop host
- `supabase/functions/notify-pm` — authenticated Make webhook proxy for PM email
- `supabase/functions/watch-pair` — Wear pairing create/redeem
- `supabase/migrations/` — RLS + private secrets support
- `scripts/packaging/` — Windows ZIP / Inno, Android APK, Wear APK helpers

## Notifications

Never put `MAKE_EMAIL_WEBHOOK_URL` in the Flutter client.
Rotate the Make webhook via Edge secret or `private.app_secrets`.
PM notifications are **email only** (no SMS / email-to-SMS gateways).

## Packaging

See README for portable Windows ZIP, per-user Inno installer, Android APK, and Wear APK.
