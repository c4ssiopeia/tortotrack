import 'package:intl/intl.dart';

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
// The interpolated weights are never stored — they only exist for the math.
//
// Returns a map of { 'YYYY-MM-DD' -> trend_value_in_kg } for every
// calendar day from the first to the last real entry, including gap days.
Map<String, double> calculateTrend(Map<String, double> realEntries) {
  if (realEntries.isEmpty) return {};

  final sortedDates = realEntries.keys.toList()..sort();
  final result = <String, double>{};

  double? previousTrend;
  DateTime? previousDate;
  double? previousWeight;

  for (final dateStr in sortedDates) {
    final currentDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    final currentWeight = realEntries[dateStr]!;

    if (previousTrend == null) {
      // First entry: trend starts equal to the measured weight.
      previousTrend = currentWeight;
      result[dateStr] = previousTrend;
    } else {
      // Fill gap days with linearly interpolated virtual weights.
      final gapDays = currentDate.difference(previousDate!).inDays;
      for (int i = 1; i < gapDays; i++) {
        final fraction = i / gapDays;
        final virtualWeight =
            previousWeight! + fraction * (currentWeight - previousWeight);
        previousTrend = previousTrend! + 0.1 * (virtualWeight - previousTrend!);
        final virtualDate = previousDate.add(Duration(days: i));
        result[DateFormat('yyyy-MM-dd').format(virtualDate)] = previousTrend!;
      }

      // Apply the formula for the real entry.
      previousTrend = previousTrend! + 0.1 * (currentWeight - previousTrend!);
      result[dateStr] = previousTrend!;
    }

    previousDate = currentDate;
    previousWeight = currentWeight;
  }

  return result;
}
