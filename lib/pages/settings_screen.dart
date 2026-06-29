import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../database/database.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionHeader('Appearance'),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, __) => SwitchListTile(
            title: const Text('Dark mode'),
            value: mode == ThemeMode.dark,
            onChanged: (value) async {
              themeNotifier.value =
                  value ? ThemeMode.dark : ThemeMode.light;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('darkMode', value);
            },
          ),
        ),
        const Divider(),
        _SectionHeader('Units'),
        ValueListenableBuilder<bool>(
          valueListenable: useLbsNotifier,
          builder: (_, useLbs, __) => SwitchListTile(
            title: const Text('Display in pounds (lbs)'),
            subtitle: const Text('Weight is always stored in kg'),
            value: useLbs,
            onChanged: (value) async {
              useLbsNotifier.value = value;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('useLbs', value);
            },
          ),
        ),
        const Divider(),
        _SectionHeader('Export & Import'),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export as CSV'),
          subtitle: const Text('Saves all entries to your Documents folder'),
          onTap: () => _exportCsv(context),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Import from CSV'),
          subtitle: const Text('Coming soon'),
          enabled: false,
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: const Text('Export as PDF'),
          subtitle: const Text('Coming soon'),
          enabled: false,
        ),
        const Divider(),
        _SectionHeader('Data'),
        ListTile(
          leading: const Icon(Icons.date_range_outlined),
          title: const Text('Delete by date range'),
          subtitle: const Text('Coming soon'),
          enabled: false,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text(
            'Delete all data',
            style: TextStyle(color: Colors.red),
          ),
          subtitle: const Text('Permanently removes all weight entries'),
          onTap: () => _confirmDeleteAll(context),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final entries = await db.getAllEntries();
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
      }
      return;
    }

    final buffer = StringBuffer('date,weight_kg\n');
    for (final e in entries) {
      buffer.writeln('${e.date},${e.weightKg}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(p.join(dir.path, 'tortotrack_$timestamp.csv'));
    await file.writeAsString(buffer.toString());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently removes every weight entry. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete all',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await db.deleteAllEntries();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
