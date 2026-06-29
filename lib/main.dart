import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/app_colors.dart';
import 'pages/table_screen.dart';
import 'pages/graph_screen.dart';
import 'pages/settings_screen.dart';
import 'database/database.dart';

// Global notifiers so any widget can read or change app-wide preferences
// without needing to pass callbacks all the way down the widget tree.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
// true = display weights in lbs; false = kg (storage is always kg).
final useLbsNotifier = ValueNotifier<bool>(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  useLbsNotifier.value = prefs.getBool('useLbs') ?? false;
  await db.seedDummyData();
  runApp(const MainApp());
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
