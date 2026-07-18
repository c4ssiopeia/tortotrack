import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../database/database.dart';
import '../src/csv_io.dart';

enum _ExportFormat { simple, fourmilab }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _ExportFormat _exportFormat = _ExportFormat.simple;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('exportFormat');
    if (saved == 'fourmilab') {
      setState(() => _exportFormat = _ExportFormat.fourmilab);
    }
  }

  Future<void> _setExportFormat(_ExportFormat fmt) async {
    setState(() => _exportFormat = fmt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exportFormat', fmt.name);
  }

  Future<void> _setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme',
        mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.dark
                ? 'dark'
                : 'system');
  }

  Future<void> _setGoal(WeightGoal goal) async {
    goalNotifier.value = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goal', goal.name);
  }

  Future<void> _setDecimalSeparator(DecimalSeparator separator) async {
    decimalSeparatorNotifier.value = separator;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('decimalSeparator', separator.name);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SectionHeader('Goal'),
        ValueListenableBuilder<WeightGoal>(
          valueListenable: goalNotifier,
          builder: (_, goal, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<WeightGoal>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WeightGoal.lose,
                    label: Text('Lose'),
                  ),
                  ButtonSegment(
                    value: WeightGoal.maintain,
                    label: Text('Maintain'),
                  ),
                  ButtonSegment(
                    value: WeightGoal.gain,
                    label: Text('Gain'),
                  ),
                ],
                selected: {goal},
                onSelectionChanged: (s) => _setGoal(s.first),
              ),
            ),
          ),
        ),
        const Divider(),
        _SectionHeader('Appearance'),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => _setTheme(s.first),
              ),
            ),
          ),
        ),
        const Divider(),
        _SectionHeader('Units'),
        ValueListenableBuilder<bool>(
          valueListenable: useLbsNotifier,
          builder: (_, useLbs, _) => SwitchListTile(
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
        _SectionHeader('Number format'),
        ValueListenableBuilder<DecimalSeparator>(
          valueListenable: decimalSeparatorNotifier,
          builder: (_, separator, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Decimal separator'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DecimalSeparator>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: DecimalSeparator.dot,
                        label: Text('Dot'),
                      ),
                      ButtonSegment(
                        value: DecimalSeparator.comma,
                        label: Text('Comma'),
                      ),
                    ],
                    selected: {separator},
                    onSelectionChanged: (s) => _setDecimalSeparator(s.first),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Example: ${separator == DecimalSeparator.dot ? '90.00 kg' : '90,00 kg'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        _SectionHeader('Export & Import'),
        // Export format toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text('Export format:'),
              const SizedBox(width: 16),
              SegmentedButton<_ExportFormat>(
                segments: const [
                  ButtonSegment(
                    value: _ExportFormat.simple,
                    label: Text('Simple'),
                    icon: Icon(Icons.list_outlined),
                  ),
                  ButtonSegment(
                    value: _ExportFormat.fourmilab,
                    label: Text('Fourmilab'),
                    icon: Icon(Icons.science_outlined),
                  ),
                ],
                selected: {_exportFormat},
                onSelectionChanged: (s) => _setExportFormat(s.first),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export as CSV'),
          subtitle: Text(
            _exportFormat == _ExportFormat.simple
                ? 'Simple format — date, weight in kg. Choose a local folder.'
                : 'Fourmilab Hacker\'s Diet format. Choose a local folder.',
          ),
          onTap: () => _exportCsv(context),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share CSV'),
          subtitle: const Text(
            'Send to another app — Nextcloud, email, etc.',
          ),
          onTap: () => _shareCsv(context),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('Import from CSV'),
          subtitle: const Text('Auto-detects simple or Fourmilab format'),
          onTap: () => _importCsv(context),
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

  // Builds the CSV bytes + filename for the currently selected export
  // format, or null (after showing a snackbar) if there's nothing to export.
  Future<({Uint8List bytes, String fileName})?> _prepareExport(
      BuildContext context) async {
    final entries = await db.getAllEntries();
    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
      }
      return null;
    }

    final csv = _exportFormat == _ExportFormat.simple
        ? buildSimpleCsv(entries)
        : buildFourmilabCsv(entries);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final formatTag = _exportFormat == _ExportFormat.simple ? 'simple' : 'fourmilab';
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'tortotrack_${formatTag}_$timestamp.csv';
    return (bytes: bytes, fileName: fileName);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final prepared = await _prepareExport(context);
    if (prepared == null) return;
    final (:bytes, :fileName) = prepared;

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export weight data as CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );

    if (outputPath == null) return; // user cancelled the dialog

    // On Android/iOS the plugin writes the file itself from `bytes` via the
    // system's Storage Access Framework. On desktop it only returns the
    // chosen path and leaves writing the file to us.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(outputPath).writeAsBytes(bytes);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $outputPath'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // Hands the CSV to another app (Nextcloud, email, etc.) via the OS share
  // sheet instead of the SAF "Save As" dialog. This matters specifically for
  // cloud-backed destinations: file_picker's saveFile() writes bytes
  // synchronously on the UI thread, which is unreliable once the other end
  // of that write is a network upload (Android can cut it short, leaving an
  // empty file, with no error). Sharing hands the file to the receiving app
  // instead, which uploads it on its own terms — the standard Android way
  // to pass a file to another app.
  Future<void> _shareCsv(BuildContext context) async {
    final prepared = await _prepareExport(context);
    if (prepared == null) return;
    final (:bytes, :fileName) = prepared;

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: 'Import weight data (simple or Fourmilab format)',
    );

    if (result == null || result.files.single.path == null) return;

    final content = await File(result.files.single.path!).readAsString();
    final entries = parseCsv(content);

    if (entries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid entries found in the file.')),
        );
      }
      return;
    }

    for (final e in entries) {
      await db.upsertEntry(e.date, e.weightKg);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${entries.length} entries.'),
          duration: const Duration(seconds: 4),
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
