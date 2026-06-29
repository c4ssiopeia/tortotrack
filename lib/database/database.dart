import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'weight_entry.dart';

part 'database.g.dart';

// Table definition: one row per day, date is the primary key.
// Weight is always stored in kg; conversion to lbs happens in the UI.
class WeightEntries extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD
  RealColumn get weightKg => real()();

  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(tables: [WeightEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationSupportDirectory();
      final file = File(p.join(dbFolder.path, 'tortotrack.db'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // All entries for a given month, sorted by date ascending.
  Future<List<WeightEntry>> getEntriesForMonth(int year, int month) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return (select(weightEntries)
          ..where((t) => t.date.like('$prefix%'))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  // All entries ever recorded, sorted by date ascending.
  // Used for CSV export and the trend calculation.
  Future<List<WeightEntry>> getAllEntries() {
    return (select(weightEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  // Single entry for a specific date, or null if none exists.
  Future<WeightEntry?> getEntryForDate(String date) {
    return (select(weightEntries)..where((t) => t.date.equals(date)))
        .getSingleOrNull();
  }

  // Insert a new entry or update the weight if the date already exists.
  Future<void> upsertEntry(String date, double weightKg) {
    return into(weightEntries).insertOnConflictUpdate(
      WeightEntriesCompanion(
        date: Value(date),
        weightKg: Value(weightKg),
      ),
    );
  }

  // Permanently delete the entry for a specific date.
  Future<void> deleteEntry(String date) {
    return (delete(weightEntries)..where((t) => t.date.equals(date))).go();
  }

  // Permanently delete every entry. Used in Settings.
  Future<void> deleteAllEntries() {
    return delete(weightEntries).go();
  }

  // Live stream of all entries sorted ascending — emits whenever the table changes.
  Stream<List<WeightEntry>> watchAllEntries() {
    return (select(weightEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  // Live stream of entries for a given month, sorted ascending.
  Stream<List<WeightEntry>> watchEntriesForMonth(int year, int month) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return (select(weightEntries)
          ..where((t) => t.date.like('$prefix%'))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  // Seeds 10 days of dummy data, only if the database is currently empty.
  Future<void> seedDummyData() async {
    final existing = await getAllEntries();
    if (existing.isNotEmpty) return;

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
