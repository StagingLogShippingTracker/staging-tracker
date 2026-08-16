# Swift Staging & Shipping Log — Wear OS

Minimal Flutter client for Wear OS watches. Signs in via a short-lived pairing
code from the Windows/Android **Pair Watch** Settings action (`watch-pair`
Edge Function), then lists active staging, confirms ship, and runs a lean
staging verification walk (SVR-style).

## Prerequisites

- Flutter SDK 3.44+ with Android toolchain (JDK 17 + Android SDK)
- A Wear OS emulator or physical watch
- Main Swift Staging & Shipping Log app signed in to create a pairing code (Settings → Pair Watch)

## Configure

Uses the same public Supabase URL + anon key defaults as the main app
(`packages/swift_staging_shared`). Override if needed:

```powershell
flutter run -d <wear-device> `
  --dart-define=SUPABASE_URL=https://….supabase.co `
  --dart-define=SUPABASE_ANON_KEY=…
```

## Run (dev)

From this directory:

```powershell
# From repo root if using vendored SDK:
..\..\.tools\flutter\bin\flutter.bat pub get
..\..\.tools\flutter\bin\flutter.bat run -d <wear-device>
```

Or from repo root:

```powershell
.\.tools\flutter\bin\flutter.bat -C apps\wear pub get
.\.tools\flutter\bin\flutter.bat -C apps\wear run -d <wear-device>
```

## Pairing flow

1. On Windows or Android: Settings → **Pair Watch** → generate code.
2. On the watch: enter the 6-digit code on the Pair screen.
3. Session is stored via Supabase Auth; reopen the app stays signed in until sign-out.

## Build APK

```powershell
# From repo root:
.\scripts\packaging\build-wear-apk.ps1
```

Output: `dist/SwiftStagingLog-Wear.apk` (sideload / Wear install).

## Screens

| Screen | Purpose |
|--------|---------|
| Pair | Redeem pairing code |
| Home | Active staging list |
| Ship | Confirm ship for one entry |
| Verify | Lean warehouse-order verify (Yes / Skip) |

## Notes

- Industrial dark theme (system sans — not Oswald-heavy).
- Shared domain/ops live in `packages/swift_staging_shared` (`ShipOperations`,
  `WatchPairingClient`, audit location order).
- No Prophet21 / Epicor / PWA.
