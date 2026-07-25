# SLST QA Error Report

Updated during professional polish / parity / multi-platform restore.
Status section refreshed 2026-07-25 against current `lib/` (see `docs/senior-assessment.md`).

## P0 — Fixed

| ID | Issue | Location | Status |
|----|-------|----------|--------|
| P0-1 | F1–F4 dock chips had no keyboard shortcuts | `command_dock.dart`, `app_shell.dart` | **Done** — `CallbackShortcuts` + `LogicalKeyboardKey` |
| P0-2 | Dashboard dumped Future / Corp / Customer into “Awaiting” | `dashboard_screen.dart` `_columnFor` | **Done** — dedicated columns |
| P0-3 | Orders KPI unioned staging + shipped | `app_state.dart` `orderCount` | **Done** — staging-only unique SOs |
| P0-4 | Shipped KPI included RETURNED TO STOCK / CONSOLIDATED | `app_state.dart` `containerTotals` | **Done** — filtered |
| P0-5 | Floor map zones / sub-slots not clickable | `warehouse_floor_map.dart` | **Done** — zone + slot drill-downs |

## P1 — Parity

| ID | Issue | Status |
|----|-------|--------|
| P1-1 | Overdue prompt UI unused (`overdueHandled`) | **Done** — dashboard prompt + `markOverdueHandled`; industrial dialog styling |
| P1-2 | Memory × (`hideMemory`) unused | **Done** — wired in `location_selector.dart` |
| P1-3 | Quick Consolidate dialog unwired | **Done** — dock → `showQuickConsolidateDialog` |
| P1-4 | Dashboard Quick Search | **Done** — `_matchesQuickSearch` + search field |
| P1-5 | SO → customer autofill | **Done** — staging form + quick ship sheets |
| P1-6 | Status label / reports alignment | **Done** — shared `StatusRules.formatUi` on board + reports |
| P1-7 | Order Inspector actions | **Done** — Edit / Ship / Split / History |

## Platforms

| ID | Issue | Status |
|----|-------|--------|
| PL-1 | `android/` missing on branch | **Done** — restored; adaptive shell |
| PL-2 | Wear client missing | **Done** — `apps/slst_wear` + Settings Pair Watch |
| PL-3 | AGENTS.md Windows-only contradiction | **Done** — Win+Android+Wear docs |

## Packaging note (this cloud environment)

Windows Inno/ZIP and Android/Wear APK rebuilds require Windows + Android SDKs. This Linux agent run verified `flutter analyze` (no errors) and `flutter test` (all passed). Run packaging scripts on a Windows/dev machine with Flutter + VS/Android SDK:

- `scripts/packaging/build-windows-installer.ps1`
- `scripts/packaging/build-android-apk.ps1`
- `scripts/packaging/build-wear-apk.ps1`
