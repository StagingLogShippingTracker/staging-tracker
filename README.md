# SLST — Staging Log & Shipping Tracker (Flutter)

Native Flutter client for Swift Supply staging and shipping operations.
Targets **Windows** (portable ZIP + per-user installer) and **Android** (sideload APK).
Uses the existing hosted Supabase project for Auth, Postgres, Storage, and the `notify-pm` Edge Function (Make.com notifications).

> The previous GitHub Pages HTML/PWA app has been removed. Users need a packaged Windows or Android build.

## Stack

- Flutter / Dart (Material 3)
- Riverpod (state), GoRouter (navigation)
- `supabase_flutter` (Auth, Database, Storage, Functions)
- Make.com notifications via authenticated Edge Function `notify-pm` (webhook URL is **not** embedded in the app)

## Prerequisites

- Flutter SDK 3.44+ (this repo may keep a local copy under `.tools/flutter`, which is gitignored)
- For Windows builds: Visual Studio with **Desktop development with C++**
- For Android builds: Android SDK + JDK 17
- Optional: Inno Setup 6 for the per-user Windows installer

```powershell
# From repo root, if using the vendored SDK:
.\.tools\flutter\bin\flutter.bat doctor
.\.tools\flutter\bin\flutter.bat pub get
```

## Run (dev)

```powershell
.\.tools\flutter\bin\flutter.bat run -d windows
# or
.\.tools\flutter\bin\flutter.bat run -d android
```

Anonymous users are **read-only**. Sign in with a confirmed Supabase email/password account to create/edit/ship/notify.

## Configuration

`lib/core/app_config.dart` holds the public Supabase URL + anon key (override with `--dart-define=SUPABASE_URL=...` / `SUPABASE_ANON_KEY=...` if needed).

Server-only Make webhook:

- Preferred: Edge Function secret `MAKE_EMAIL_WEBHOOK_URL`
- Fallback: `private.app_secrets` row `MAKE_EMAIL_WEBHOOK_URL` (read by `public.get_app_secret` as `service_role` only)

PM SMS routing lives **only** inside `supabase/functions/notify-pm`.

## Tests

```powershell
.\.tools\flutter\bin\flutter.bat test
.\.tools\flutter\bin\flutter.bat analyze
```

## Packaging

### Windows portable ZIP

```powershell
.\scripts\packaging\build-windows-portable.ps1
```

Output: `dist/slst-windows-portable.zip`

### Windows per-user installer (no admin)

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
.\scripts\packaging\build-windows-installer.ps1
```

Output: `dist/SLST-Setup-User.exe` (installs under `%LOCALAPPDATA%\Programs\SLST`)

### Android APK

```powershell
.\scripts\packaging\build-android-apk.ps1
```

For release signing, create `android/key.properties` (gitignored) pointing at a keystore. Without it, the script builds a debug APK suitable for internal sideload testing.

## CI

GitHub Actions workflow `.github/workflows/build.yml` builds Windows and Android artifacts on push/tag.
GitHub Pages is **not** used.

## Backend notes

- Tables: `staging`, `shipped`, `changelog`, `dropdown_roster`
- Storage bucket: `freight-photos` (public read, authenticated write)
- RLS: anonymous **select** only; writes require authenticated session
- No Prophet21 / Epicor / Search Order integration

## Remembered entry fields and locations

Customer, Staged By, Shipped By, Carrier, and other person-by fields accept
either a searchable remembered value or free text. A new value is written to
`dropdown_roster` only after the business operation succeeds. Values hidden in
local memory and operational sentinels such as `CONSOLIDATED` and
`RETURNED TO STOCK` are excluded from suggestions.

Every editable location uses a drill-in selector with four categories:

- **Aisle Location** — normalized aisle bins such as `A-01-A-1`,
  `A-01-A-2`, and `A-01-A-1+2`
- **Floor Locations**
- **Stage for Shipping**
- **Outside**

Existing values are classified deterministically. The category selected by the
user is retained for a newly typed ambiguous value through category-specific
`dropdown_roster` entries; no database schema change is required.

Location occupancy is calculated only from current `staging` rows. Shipped
records and recent movement/history data are displayed as context but never
mark a bin occupied. Before assigning a conflicting bin, the app refreshes its
read model and presents an advisory with proceed or authenticated consolidation
choices. This is intentionally not a transactional lock: another user can
change staging between the advisory and the eventual save, so warehouse users
must still resolve concurrent conflicts when warned.

## Brand assets

- `assets/slst-mark.png` — forklift-in-tire brand mark (transparent background)
- `assets/slst-wordmark.png` — "SLST / Staging Log & Shipping Tracker" wordmark
- `assets/staging-shipping-logo.png` — legacy horizontal logo (kept for reference, not bundled)
- `assets/contacts.json` (employee directory)
- Regenerate app icons / splash logos with `python scripts/generate-app-icons.py`
- Additional brand files under `brand/`
