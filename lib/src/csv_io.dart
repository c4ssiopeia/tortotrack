import 'package:intl/intl.dart';
import '../database/weight_entry.dart';

// Detects whether [content] is a Fourmilab Hacker's Diet export or the simple
// tortotrack format (date,weight_kg), then parses and returns all valid entries.
//
// Fourmilab quirks handled:
//   - Days with no measurement have an empty weight column — skipped.
//   - The Preferences line declares the unit (kilogram or pound); pound values
//     are converted to kg automatically.
//   - Non-data header rows (Epoch, User, Preferences, Diet-Plan, Date, StartTrend)
//     are ignored because they don't start with a YYYY-MM-DD date.
List<WeightEntry> parseCsv(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final firstLine = lines.isNotEmpty ? lines.first.trim() : '';

  final isFourmilab = firstLine.startsWith('Epoch,') ||
      content.contains('Date,Weight,Rung,Flag,Comment');

  // Check if the fourmilab file tracks in pounds (column 2 of Preferences line).
  double conversionFactor = 1.0;
  if (isFourmilab) {
    for (final line in lines) {
      if (line.startsWith('Preferences,')) {
        final cols = line.split(',');
        if (cols.length > 2 && cols[2].trim().toLowerCase() == 'pound') {
          conversionFactor = 1.0 / 2.20462;
        }
        break;
      }
    }
  }

  final entries = <WeightEntry>[];
  final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2},');

  for (final raw in lines) {
    final line = raw.trim();
    if (!datePattern.hasMatch(line)) continue;

    final cols = line.split(',');
    if (cols.length < 2) continue;

    final date = cols[0].trim();
    final weightStr = cols[1].trim();
    if (weightStr.isEmpty) continue; // Fourmilab day with no measurement

    final weight = double.tryParse(weightStr);
    if (weight == null || weight <= 0) continue;

    entries.add(WeightEntry(date: date, weightKg: weight * conversionFactor));
  }

  return entries;
}

// Produces the simple two-column tortotrack format:
//   date,weight_kg
//   YYYY-MM-DD,XX.X
String buildSimpleCsv(List<WeightEntry> entries) {
  final buf = StringBuffer('date,weight_kg\n');
  for (final e in entries) {
    buf.writeln('${e.date},${e.weightKg}');
  }
  return buf.toString();
}

// Produces a Fourmilab Hacker's Diet compatible CSV export.
//
// Structure:
//   Global header (Epoch, User, Preferences, Diet-Plan)
//   One block per month containing entries, with:
//     - Date,Weight,Rung,Flag,Comment header
//     - StartTrend row (EMA trend value at start of that month)
//     - One row per calendar day (empty weight if no measurement that day)
//
// The StartTrend for each month after the first is the EMA trend value at
// the last day of the previous month, computed via calculateTrend().
String buildFourmilabCsv(List<WeightEntry> entries) {
  if (entries.isEmpty) return '';

  final now = DateTime.now().toUtc();
  // ISO 8601 without sub-second precision, e.g. 2026-07-01T12:00:00Z
  final epoch = '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}T'
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}Z';

  final weightMap = <String, double>{
    for (final e in entries) e.date: e.weightKg,
  };
  final trend = calculateTrend(weightMap);

  // Group entries by YYYY-MM
  final byMonth = <String, Map<String, double>>{};
  for (final e in entries) {
    final month = e.date.substring(0, 7);
    byMonth.putIfAbsent(month, () => {})[e.date] = e.weightKg;
  }
  final sortedMonths = byMonth.keys.toList()..sort();

  final buf = StringBuffer();
  buf.writeln('Epoch,$epoch,,,,,,');
  buf.writeln('User,1,tortotrack,,,,,,');
  buf.writeln('Preferences,1,kilogram,kilogram,calorie,0,.,');
  buf.writeln('Diet-Plan,1,0,0,0,,1,');

  final fmt = DateFormat('yyyy-MM-dd');

  for (int mi = 0; mi < sortedMonths.length; mi++) {
    final month = sortedMonths[mi];
    final year = int.parse(month.substring(0, 4));
    final monthNum = int.parse(month.substring(5, 7));

    final firstDay = DateTime.utc(year, monthNum, 1);
    final firstDayTs = firstDay.millisecondsSinceEpoch ~/ 1000;

    // StartTrend: trend value at end of previous month, or 0 for the first block.
    double startTrend = 0;
    if (mi > 0) {
      // DateTime.utc(year, monthNum, 0) = last day of the previous month.
      final lastDayOfPrev = DateTime.utc(year, monthNum, 0);
      final lastDayStr = fmt.format(lastDayOfPrev);
      if (trend.containsKey(lastDayStr)) {
        startTrend = trend[lastDayStr]!;
      } else {
        // Gap between months: use the most recent trend value before this month.
        final before = trend.keys
            .where((d) => d.compareTo(month) < 0)
            .toList()
          ..sort();
        if (before.isNotEmpty) startTrend = trend[before.last]!;
      }
    }

    buf.writeln('Date,Weight,Rung,Flag,Comment,,,');
    buf.writeln('StartTrend,$startTrend,0,$firstDayTs,$firstDayTs,1,,');

    final lastDay = DateTime.utc(year, monthNum + 1, 0).day;
    final monthMap = byMonth[month]!;

    for (int day = 1; day <= lastDay; day++) {
      final dateStr = fmt.format(DateTime.utc(year, monthNum, day));
      final weight = monthMap[dateStr];
      final weightStr = weight != null ? weight.toString() : '';
      buf.writeln('$dateStr,$weightStr,,0,,,,');
    }
  }

  return buf.toString();
}
