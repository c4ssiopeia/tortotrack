import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'src/app_colors.dart';
import 'pages/table_screen.dart';
import 'pages/graph_screen.dart';
import 'pages/settings_screen.dart';
import 'database/database.dart';

enum WeightGoal { lose, maintain, gain }

// Global notifiers so any widget can read or change app-wide preferences
// without needing to pass callbacks all the way down the widget tree.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
// true = display weights in lbs; false = kg (storage is always kg).
final useLbsNotifier = ValueNotifier<bool>(false);
// Goal drives the trend coloring: Lose/Maintain/Gain.
final goalNotifier = ValueNotifier<WeightGoal>(WeightGoal.lose);
// Shared month shown in both table and graph — keeps them in sync across tabs.
final monthNotifier = ValueNotifier<DateTime>(
  DateTime(DateTime.now().year, DateTime.now().month),
);

void main() {
  runZonedGuarded(_startup, _showCrashScreen);
}

Future<void> _startup() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    _showCrashScreen(details.exception, details.stack ?? StackTrace.empty);
  };

  // On desktop platforms (Linux, Windows, macOS) sqflite needs the FFI
  // backend because there is no platform channel to the OS's built-in SQLite.
  // sqfliteFfiInit() loads the system libsqlite3 and sets databaseFactory to
  // databaseFactoryFfi so that all subsequent openDatabase() calls go through FFI.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // One-shot migration: move the database from the old NativeDatabase path
  // (getApplicationSupportDirectory) to the new sqflite path (getDatabasesPath).
  // Silent — a fresh empty database is created if anything goes wrong.
  await _migrateLegacyDatabase();

  final prefs = await SharedPreferences.getInstance();
  // Migrate old 'darkMode' bool to new 'theme' string key.
  final themeStr = prefs.getString('theme') ??
      (prefs.getBool('darkMode') == true ? 'dark' : 'system');
  themeNotifier.value = switch (themeStr) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  goalNotifier.value = switch (prefs.getString('goal') ?? 'lose') {
    'maintain' => WeightGoal.maintain,
    'gain' => WeightGoal.gain,
    _ => WeightGoal.lose,
  };
  useLbsNotifier.value = prefs.getBool('useLbs') ?? false;
  if (kDebugMode) await db.seedDummyData();
  runApp(const MainApp());
}

// Moves the database from the old NativeDatabase directory to the sqflite
// directory so data is not lost when upgrading from the previous build.
Future<void> _migrateLegacyDatabase() async {
  try {
    final appDir = await getApplicationSupportDirectory();
    final oldFile = File(p.join(appDir.path, 'tortotrack.db'));
    if (!oldFile.existsSync()) return;

    final newDir = await sqflite.getDatabasesPath();
    final newFile = File(p.join(newDir, 'tortotrack.db'));
    if (newFile.existsSync()) return; // already migrated

    await oldFile.copy(newFile.path);
  } catch (_) {
    // Best-effort; a clean empty database will be created if this fails.
  }
}

// Returns the color for a trend value based on whether it is moving toward
// the user's goal. Compares today's trend value to the previous day's.
// Returns a neutral orange when either value is missing (first entry, restart).
Color goalColor({
  required double? currentTrend,
  required double? previousTrend,
  required WeightGoal goal,
  required bool isDark,
}) {
  // Neutral = orange (the EMA trend line colour). Used when there is no
  // comparison possible, when the trend is flat, or for the Maintain goal.
  final neutral = isDark ? Colors.orange[300]! : Colors.deepOrange;
  if (currentTrend == null || previousTrend == null) return neutral;
  if (goal == WeightGoal.maintain) return neutral;
  final delta = currentTrend - previousTrend;
  if (delta.abs() < 0.01) return neutral;
  final good = isDark ? Colors.green[300]! : Colors.green[700]!;
  final bad = isDark ? Colors.red[300]! : Colors.red[700]!;
  return switch (goal) {
    WeightGoal.lose => delta < 0 ? good : bad,
    WeightGoal.gain => delta > 0 ? good : bad,
    WeightGoal.maintain => neutral,
  };
}

// Catches any unhandled Dart exception and shows it on screen so we can
// read the error message without needing a logcat reader or debugger.
void _showCrashScreen(Object error, StackTrace stack) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'tortotrack crashed',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
              const SizedBox(height: 12),
              Text(error.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(stack.toString(),
                  style:
                      const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    ),
  ));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.oceanBlue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.oceanBlue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('tortotrack'),
          backgroundColor: AppColors.oceanBlue,
          foregroundColor: AppColors.background,
          scrolledUnderElevation: 4.0,
          bottom: const TabBar(
            labelColor: AppColors.background,
            unselectedLabelColor: AppColors.background,
            tabs: [
              Tab(icon: Icon(Icons.table_view_outlined)),
              Tab(icon: Icon(Icons.show_chart_outlined)),
              Tab(icon: Icon(Icons.settings_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TableScreen(),
            GraphScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}
