import 'package:intl/intl.dart';

// Plain data class — one row from the weight_entries table.
class WeightEntry {
  final String date;      // YYYY-MM-DD
  final double weightKg;
  const WeightEntry({required this.date, required this.weightKg});
}

// Formats a DateTime to the YYYY-MM-DD string used as the database key.
String dateToString(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

// Parses a YYYY-MM-DD string back to a DateTime (at midnight).
DateTime stringToDate(String date) {
  return DateFormat('yyyy-MM-dd').parse(date);
}

// Hacker's Diet exponential moving average trend formula:
//   T_today = T_yesterday + 0.1 * (W_today - T_yesterday)
//
// For the very first entry there is no previous trend, the trend
// starts equal to the first measured weight.
//
// When days are missing between two real entries we linearly interpolate
// virtual weight values for each gap day and feed them through the formula.
//
// Gaps longer than [maxGapDays] cause a full restart: the trend resets to
// the new weight, just like the very first entry. The gap days are not
// written to the result map, so the graph shows a visible hole in the
// trend line rather than a fabricated curve.
//
// Returns a record with:
//   trend     — { 'YYYY-MM-DD' -> EMA trend value in kg } for all real entries
//               and interpolated gap days.
//   estimates — { 'YYYY-MM-DD' -> interpolated weight in kg } for gap days
//               only — the synthetic values the EMA formula used internally,
//               exposed so the UI can show them in the table.
({Map<String, double> trend, Map<String, double> estimates})
    calculateTrendWithEstimates(
  Map<String, double> realEntries, {
  int maxGapDays = 7,
}) {
  if (realEntries.isEmpty) return (trend: {}, estimates: {});

  final sortedDates = realEntries.keys.toList()..sort();
  final trendOut = <String, double>{};
  final estimatesOut = <String, double>{};

  double? previousTrend;
  DateTime? previousDate;
  double? previousWeight;

  for (final dateStr in sortedDates) {
    final currentDate = _dateFromString(dateStr);
    final currentWeight = realEntries[dateStr]!;

    if (previousTrend == null) {
      previousTrend = currentWeight;
      trendOut[dateStr] = previousTrend;
    } else {
      final gapDays = currentDate.difference(previousDate!).inDays;
      final showGap = gapDays > maxGapDays;

      if (showGap) {
        // Long break: restart the EMA fresh from the new weight.
        previousTrend = currentWeight;
      } else {
        // Short gap: interpolate virtual days and continue the EMA.
        for (int i = 1; i < gapDays; i++) {
          final fraction = i / gapDays;
          final virtualWeight =
              previousWeight! + fraction * (currentWeight - previousWeight);
          previousTrend = previousTrend! + 0.1 * (virtualWeight - previousTrend);
          final virtualDate = previousDate.add(Duration(days: i));
          final vStr = _stringFromDate(virtualDate);
          trendOut[vStr] = previousTrend;
          estimatesOut[vStr] = virtualWeight;
        }
        previousTrend = previousTrend! + 0.1 * (currentWeight - previousTrend);
      }
      trendOut[dateStr] = previousTrend;
    }

    previousDate = currentDate;
    previousWeight = currentWeight;
  }

  return (trend: trendOut, estimates: estimatesOut);
}

// Convenience wrapper — returns only the trend map. All existing callers
// continue to work unchanged.
Map<String, double> calculateTrend(
  Map<String, double> realEntries, {
  int maxGapDays = 7,
}) =>
    calculateTrendWithEstimates(realEntries, maxGapDays: maxGapDays).trend;

// Parses a YYYY-MM-DD string as a UTC date for gap arithmetic inside
// calculateTrendWithEstimates. UTC has no DST shifts, so the difference between
// two UTC
// midnights is always an exact number of calendar days regardless of what
// timezone or DST rules the device uses.
DateTime _dateFromString(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

// Formats a UTC DateTime back to a YYYY-MM-DD string using its UTC fields,
// keeping the result timezone-independent.
String _stringFromDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
