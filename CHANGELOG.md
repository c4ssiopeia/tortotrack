# Changelog

All notable changes to tortotrack will be documented here.
Versioning follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH

---

## [0.3.1] - 2026-06-30

### Fixed
- **Replaced Drift + sqlite3_flutter_libs with sqflite** — the previous setup bundled a compiled native SQLite `.so` library which crashed on startup on some Android devices before any Dart code ran (and therefore couldn't be caught or displayed). The app now uses Android's own built-in SQLite via `sqflite`, which is battle-tested on billions of devices and requires no native library bundling.
- **Pinned `shared_preferences_android` to `<2.4.0`** — version 2.4.x switched to AndroidX DataStore as its storage backend, which bundles `libdatastore_shared_counter.so`. This third-party native library was causing startup crashes on some devices. The 2.3.4 version uses the plain Android SharedPreferences API with no native code.
- **Pinned `path_provider_android` to `<2.3.0`** — version 2.3.x pulls in the experimental `jni` Dart package which crashes at native startup on some devices.
- **Changed Android `applicationId` from `com.example.tortotrack` to `app.tortotrack`** — the `com.example.*` namespace is a reserved development prefix that OEM Android security layers (MIUI on Xiaomi, Samsung Knox, etc.) silently kill at launch with no error message. This was the root cause of the "app installs but immediately crashes with no error screen" behavior.
- The APK now contains **only** `libflutter.so` and `libapp.so` — no third-party bundled native libraries whatsoever.
- Dropped 37 transitive Dart packages (Drift, drift_dev, build_runner, analyzer, …); the dependency tree is now much simpler.
- Added one-shot silent database migration: on first launch after this update, the database file is automatically moved from the old location (`getApplicationSupportDirectory`) to the new sqflite path (`getDatabasesPath`), preserving any existing data.
- Crash screen now ensures Flutter bindings are initialised before calling `runApp`, preventing a secondary crash if the error happened very early in startup.

---

## [0.3.0] - 2026-06-30

### Added
- **Table screen** redesigned: month navigation (< >), all days of the month shown, empty past days tappable to add missed entries, future days greyed out
- **Weekend highlighting** — Saturday/Sunday rows use a grey background (theme-aware)
- **Swipe to delete** entries with confirmation dialog
- **Trend value** shown inline in each table row (date · trend · weight), colour-coded orange
- **Graph screen** with `fl_chart` line chart: actual weight (blue dots) + Hacker's Diet EMA trend (orange curve), month navigation, rate-of-loss summary, theme-adaptive colours, touch tooltips
- **Settings screen**: dark mode toggle, kg/lbs display toggle, CSV export (saves to Documents), placeholders for CSV import / PDF export / delete by date range
- **Dark mode** support throughout; preference persisted via `shared_preferences`
- **kg/lbs toggle**: display converts everywhere (table, graph, dialogs); storage always in kg
- `MonthHeader` extracted as shared widget used by both Table and Graph screens
- Seed data function (inserts 10 dummy entries on first launch if database is empty)

### Changed
- Database: added `deleteEntry`, `watchEntriesForMonth`, `watchEntriesForMonth` stream, `seedDummyData`
- `main()` now async; loads theme and unit preferences before `runApp`

---

## [0.2.0] - 2026-06-29

### Added
- Unit tests for `calculateTrend`, `dateToString`, `stringToDate` (9 tests, all passing)
- Flutter SDK at `/srv/dev/flutter` (3.44.4) now usable by claudedev via PUB_CACHE=/srv/dev/.pub-cache
- Generated `database.g.dart` via build_runner (Drift code generation)
- `watchAllEntries()` stream on `AppDatabase` — emits on every table change
- Global `db` singleton in `database.dart` shared across all screens
- `TableScreen` wired to the database: entries load via `StreamBuilder`, new weights saved via `upsertEntry`
- Entries displayed as a scrollable list, newest first, formatted date + weight in kg
- App title fixed from placeholder to "tortotrack"

---

## [0.1.0] - 2026-06-29

### Added
- Initial Flutter project structure with 3 tabs: Table, Graph, Settings
- Weight input dialog with number validation (accepts `.` and `,` as decimal separator)
- Color palette (`app_colors.dart`)
- Project renamed from `weighttracker_app` to `tortotrack`
- PolyForm Noncommercial License 1.0.0
- README with project description, Hacker's Diet formula, and AI disclaimer
- CHANGELOG
