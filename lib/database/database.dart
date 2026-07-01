import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'weight_entry.dart';

// Manages the SQLite database via sqflite (uses Android's built-in SQLite —
// no native library bundling required, no JNI issues at startup).
class AppDatabase {
  static Database? _instance;

  // Broadcast stream controller: any mutation calls _notify() so that all
  // active watch() streams re-query and emit fresh data.
  static final _changes = StreamController<void>.broadcast();

  Future<Database> get _db async {
    _instance ??= await _openDb();
    return _instance!;
  }

  static Future<Database> _openDb() async {
    // On Android/iOS, sqflite's getDatabasesPath() is the standard location.
    // On desktop (Linux/Windows/macOS) we use getApplicationSupportDirectory()
    // because getDatabasesPath() returns an unstable path when running via FFI.
    final String dbPath;
    if (Platform.isAndroid || Platform.isIOS) {
      dbPath = p.join(await getDatabasesPath(), 'tortotrack.db');
    } else {
      final dir = await getApplicationSupportDirectory();
      await Directory(dir.path).create(recursive: true);
      dbPath = p.join(dir.path, 'tortotrack.db');
    }
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE weight_entries (
          date      TEXT PRIMARY KEY,
          weight_kg REAL NOT NULL
        )
      '''),
    );
  }

  void _notify() => _changes.add(null);

  static WeightEntry _row(Map<String, Object?> row) => WeightEntry(
        date: row['date'] as String,
        weightKg: (row['weight_kg'] as num).toDouble(),
      );

  // All entries ever recorded, sorted by date ascending.
  Future<List<WeightEntry>> getAllEntries() async {
    final rows = await (await _db).query('weight_entries', orderBy: 'date ASC');
    return rows.map(_row).toList();
  }

  // All entries for a given month, sorted by date ascending.
  Future<List<WeightEntry>> getEntriesForMonth(int year, int month) async {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final rows = await (await _db).query(
      'weight_entries',
      where: 'date LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'date ASC',
    );
    return rows.map(_row).toList();
  }

  // Single entry for a specific date, or null if none exists.
  Future<WeightEntry?> getEntryForDate(String date) async {
    final rows = await (await _db).query(
      'weight_entries',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.isEmpty ? null : _row(rows.first);
  }

  // Insert a new entry or replace the weight if the date already exists.
  Future<void> upsertEntry(String date, double weightKg) async {
    await (await _db).insert(
      'weight_entries',
      {'date': date, 'weight_kg': weightKg},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  // Permanently delete the entry for a specific date.
  Future<void> deleteEntry(String date) async {
    await (await _db)
        .delete('weight_entries', where: 'date = ?', whereArgs: [date]);
    _notify();
  }

  // Permanently delete every entry. Used in Settings.
  Future<void> deleteAllEntries() async {
    await (await _db).delete('weight_entries');
    _notify();
  }

  // Live stream of all entries — emits immediately, then again on every change.
  Stream<List<WeightEntry>> watchAllEntries() async* {
    yield await getAllEntries();
    await for (final _ in _changes.stream) {
      yield await getAllEntries();
    }
  }

  // Live stream of entries for a given month — same pattern as watchAllEntries.
  Stream<List<WeightEntry>> watchEntriesForMonth(int year, int month) async* {
    yield await getEntriesForMonth(year, month);
    await for (final _ in _changes.stream) {
      yield await getEntriesForMonth(year, month);
    }
  }

  // Seeds 10 days of dummy data, only if the database is currently empty.
  Future<void> seedDummyData() async {
    if ((await getAllEntries()).isNotEmpty) return;
    final weights = [78.4, 78.1, 78.6, 77.9, 78.3, 77.7, 77.5, 77.8, 77.2, 77.0];
    final today = DateTime.now();
    for (int i = 9; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      await upsertEntry(dateToString(date), weights[9 - i]);
    }
  }
}

// Single shared instance for the whole app.
final db = AppDatabase();
