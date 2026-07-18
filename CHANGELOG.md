# Changelog

All notable changes to tortotrack will be documented here.
Versioning follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH

---

## [Planned]

- **OWASP injection testing** — audit all user-facing inputs (weight entry, CSV
  import, date fields) against OWASP injection categories: SQL injection, path
  traversal, and malformed input edge cases. Fix any gaps found.
- **Delete by date range** — UI for removing entries within a selected date range.
- **PDF export** — monthly summary as a shareable PDF.

---

## [0.5.4] - 2026-07-18

### Fixed
- **Sharing the CSV directly to Nextcloud produced an empty file.** Root
  cause (confirmed against Android's own SAF documentation and the
  `file_picker` issue tracker): `file_picker`'s "Save As" write happens
  synchronously on the app's main thread, which is fine for local storage
  but unreliable once the other end of that write is a network upload —
  Android can cut it short with no error. Added a separate **Share CSV**
  option that hands the file to another app via Android's standard share
  mechanism (`share_plus`) instead, which is built for exactly this and
  doesn't have the problem. "Export as CSV" (Save As, for local folders)
  is unchanged and still works as before.

### Changed
- **Number format setting redesigned** — the decimal-separator toggle used
  to show only "90.00" / "90,00" as button labels, which wasn't clear on
  its own. Now the buttons are labelled "Dot" / "Comma" with a live
  "Example: 90.00 kg" preview underneath.

---

## [0.5.3] - 2026-07-18

### Fixed
- **Weights now consistently show 2 decimal places everywhere** — table
  entries, trend labels, interpolated estimates, the edit-entry dialog, and
  the graph (axis labels, tooltip, monthly change summary). Previously most
  of these rounded to 1 decimal, including the box shown when reopening an
  existing entry — which meant re-saving an entry silently dropped its
  second decimal digit. That's what caused the "second decimal disappears"
  and the empty-looking export: not the export code, a display bug that fed
  back into what got saved.

### Added
- **Settings → Number format**: choose whether numbers display with a dot
  (`90.00`) or a comma (`90,00`). Display only — CSV export always uses a
  dot so exported files stay readable by Import and other tools.

---

## [0.5.2] - 2026-07-18

### Fixed
- **CSV export could save an empty file** when sharing directly to a
  cloud-backed destination (e.g. Nextcloud) instead of local storage. Root
  cause: the `file_picker` library's Android code didn't reliably close the
  output stream on every path, so some document providers never received the
  written bytes. Fixed by updating `file_picker` (8.3.7 → 10.3.10), whose
  rewritten Android implementation guarantees the stream is closed correctly.

### Changed
- **Release signing** — release APKs were being signed with Flutter's local
  debug key (a per-machine key never meant for distribution), which made
  Android treat every new build as coming from an unknown source and refuse
  in-place updates. Added a dedicated, permanent release keystore (stored
  outside the repo) so every future release shares one signature and
  installs as a normal update. Note: this specific build still requires one
  manual uninstall since the signing key changed — every release after this
  one updates in place.

---

## [0.5.1] - 2026-07-18

### Fixed
- **CSV export now lets you choose where to save** — previously the file was
  written silently into the app's private storage folder, which isn't visible
  in a normal file manager. Export now opens a native "Save As" dialog (via
  `file_picker`) so you pick the folder and filename yourself, same as Import
  already worked.
- **Table: interpolated estimate now shows two decimal places** (`~X.XX kg`)
  instead of one, to distinguish it more clearly from real entered weights
  (which stay at one decimal, matching what a scale reports).

---

## [0.5.0] - 2026-07-01

### Added
- **Table: interpolated estimates** — empty days that fall inside a short gap
  between two real entries now show `~X.X kg` (italic) in the table row
  trailing area. This is the same linearly interpolated weight value the EMA
  engine uses internally; no new calculation, just surfaced for visibility.
  Tapping the row still opens the add-weight dialog as before.
- **Theme: Light / Dark / System picker** in Settings, replacing the old
  dark-mode switch. System is the new default on first install. Existing users
  who had dark mode set are migrated automatically; everyone else lands on System.
- **Goal: Lose / Maintain / Gain** selector in Settings. Colors the trend value
  in the table and the vertical drop-lines in the graph to show whether the
  trend is moving in the right direction: green = good, red = bad, amber = moving
  but Maintain goal active. The measured weight values are never colored.

### Changed
- `calculateTrendWithEstimates` is the new primary EMA function, returning a
  Dart 3 record `({trend, estimates})`. `calculateTrend` is now a thin wrapper
  that delegates to it — all callers continue to work unchanged.

---

## [0.4.1] - 2026-07-01

### Fixed
- **EMA restart broken by DST** — `calculateTrend` now parses date strings as UTC internally for gap arithmetic. The dates stored in the database are pure calendar labels (YYYY-MM-DD) with no time or timezone. Parsing them as local midnight meant that on the day clocks spring forward (e.g. last Sunday of March in Europe), a gap of 8 calendar days measured only 7 h 23 h in local wall time, so `inDays` returned 7 instead of 8 and the restart never triggered. Using UTC makes the calendar-day count exact for every timezone and DST rule worldwide.

### Changed
- Clarified `calculateTrend` comment: a gap > 7 days resets the EMA to the new measured weight (same as the first-ever entry), so the orange trend line starts at exactly the blue dot's value after a long break.

### Tests
- Added test: gap spanning the 2024 European DST spring-forward (2024-03-31 → 2024-04-08, 8 calendar days) must trigger a restart.
- Added test: gap longer than `maxGapDays` restarts the trend at the measured weight; gap days are absent from the result map.

---

## [0.4.0] - 2026-07-01

### Added
- **CSV Import** — tap "Import from CSV" in Settings to load a file via a native file chooser dialog. The format is detected automatically: tortotrack's own simple format (`date,weight_kg`) and the **Fourmilab Hacker's Diet** export format are both supported. Days with no measurement in the Fourmilab format are silently skipped. Fourmilab files that track weight in pounds are converted to kg on import.
- **Fourmilab export format** — the Settings screen now shows a segmented toggle ("Simple" / "Fourmilab") that selects the export format. The Fourmilab export reproduces the full monthly-block structure with `Epoch`, `User`, `Preferences`, `Diet-Plan` headers and correct `StartTrend` EMA values so the file can be re-imported into the Hacker's Diet online tool.
- **Linux desktop build** — added `sqflite_common_ffi` so SQLite works on Linux via the system `libsqlite3` (no bundled native library). Database stored in `~/.local/share/tortotrack/`. Linux binary renamed from `weighttracker_app` to `tortotrack`.
- **Anforderungskatalog** folder added to the repo (`Anforderungskatalog/`) containing the Fourmilab reference export (`hackdiet_db.csv`) and the UI wireframe sketch (`sketch-weighttracking.png`).

### Changed
- `SettingsScreen` converted from `StatelessWidget` to `StatefulWidget` to hold the export format preference (persisted in `shared_preferences`).
- Export filename now includes a format tag: `tortotrack_simple_YYYYMMDD_HHmmss.csv` or `tortotrack_fourmilab_YYYYMMDD_HHmmss.csv`.
- CSV import/export logic extracted to `lib/src/csv_io.dart` to keep the settings screen clean.

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
