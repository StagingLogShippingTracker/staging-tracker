# SLST — Staging Log & Shipping Tracker (Flutter)

Native Flutter clients for Swift Supply staging and shipping operations.
Targets **Windows** (portable ZIP + per-user installer), **Android** (sideload APK), and **Wear OS** (`apps/slst_wear`).
Uses the existing hosted Supabase project for Auth, Postgres, Storage, and the `notify-pm` Edge Function (Make.com notifications). Wear pairs via the `watch-pair` Edge Function.

> The previous GitHub Pages HTML/PWA app has been removed. There is no PWA and no Prophet21 / Epicor integration.

## Stack

- Flutter / Dart (Material 3)
- Riverpod (state), GoRouter (navigation)
- `supabase_flutter` (Auth, Database, Storage, Functions)
- Make.com notifications via authenticated Edge Function `notify-pm` (webhook URL is **not** embedded in the app)
- Production document scanner with shared Dart image processing and native offline OCR

## Offline document scanner

Every photo attachment surface includes **Scan document** without removing the
normal Camera/Gallery/File choices. The scanner supports automatic edge
detection with confidence diagnostics, draggable four-corner correction,
perspective warp, 90-degree rotation, Original/Color/Document/Grayscale/B&W
enhancement, before/after review, and multi-page add/reorder/delete/replace.
Processed pages remain JPEG images and return through the existing attachment
flow. OCR text is selectable and can be copied, but is never silently written
into an order field.

Scanning, enhancement, and OCR run on the device. No scanner image or recognized
text is transmitted unless the user later completes an existing attachment,
shipping, or notification action.

### Scanner components and licenses

- [`image` 4.8.x](https://pub.dev/packages/image), MIT: deterministic Dart
  decoding, perspective correction, and enhancement in a background isolate.
- [`flutter_ocr_native` 0.3.0](https://pub.dev/packages/flutter_ocr_native),
  MIT: maintained Flutter bridge to on-device OCR.
- Android OCR is Google ML Kit Text Recognition
  `com.google.mlkit:text-recognition:16.0.1` (Google Android SDK terms). Its
  Latin model is bundled by Gradle inside the APK, so first-run model download
  is not required.
- Windows OCR is the inbox `Windows.Media.Ocr` API (Windows SDK terms). It uses
  the installed Windows language pack and requires Windows 10 or newer.

There are no separately downloaded scanner model files to regenerate or
checksum: model packaging is deterministic from `pubspec.lock` plus the pinned
Android Maven coordinate above, while Windows supplies its signed system model.
`flutter pub get` and the packaging scripts reproduce the runtime payload.

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
# Wear OS (see apps/slst_wear/README.md):
.\.tools\flutter\bin\flutter.bat -C apps\slst_wear run -d <wear-device>
```

Anonymous users are **read-only**. Sign in with a confirmed Supabase email/password account to create/edit/ship/notify.
On Wear, open **Settings → Pair Watch** on Windows/Android, then enter the 6-digit code on the watch.

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

Output: `dist/SST-Windows-Portable.zip`

### Windows per-user installer (no admin)

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
.\scripts\packaging\build-windows-installer.ps1
```

Output: `dist/SST-Setup-User.exe` (installs under `%LOCALAPPDATA%\Programs\SLST`)

### Android APK

```powershell
.\scripts\packaging\build-android-apk.ps1
```

Output: `dist/SST-Android.apk`. For production signing, create
`android/key.properties` (gitignored) pointing at a keystore. Without it, the
release build is debug-key signed for internal sideload testing.

### Wear OS APK

```powershell
.\scripts\packaging\build-wear-apk.ps1
```

Output: `dist/SST-Wear.apk`. Details: [`apps/slst_wear/README.md`](apps/slst_wear/README.md).

Each produced artifact has a lowercase SHA-256 sidecar, such as
`dist/SST-Android.apk.sha256`.

## CI

GitHub Actions workflow `.github/workflows/build.yml` builds Windows and Android artifacts on push/tag.
Wear APK is built via `scripts/packaging/build-wear-apk.ps1` (not yet a separate CI job).
GitHub Pages is **not** used.

## Backend notes

- Tables: `staging`, `shipped`, `changelog`, `dropdown_roster`
- Storage bucket: `freight-photos` (public read, authenticated write)
- RLS: staging/shipped/changelog require authenticated **select**; all writes require auth
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
