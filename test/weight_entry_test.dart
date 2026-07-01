import 'package:flutter_test/flutter_test.dart';
import 'package:tortotrack/database/weight_entry.dart';

void main() {
  group('calculateTrend', () {
    // Helper: assert two double maps are equal within floating-point tolerance.
    void expectTrend(Map<String, double> result, Map<String, double> expected) {
      expect(result.keys, unorderedEquals(expected.keys));
      for (final key in expected.keys) {
        expect(result[key], closeTo(expected[key]!, 1e-9),
            reason: 'trend value for $key');
      }
    }

    test('empty input returns empty map', () {
      expect(calculateTrend({}), isEmpty);
    });

    test('single entry seeds the trend at the measured weight', () {
      // With only one data point there is nothing to smooth — the trend
      // simply starts at that weight.
      final result = calculateTrend({'2026-01-01': 80.0});
      expectTrend(result, {'2026-01-01': 80.0});
    });

    test('two consecutive days: trend moves 10 % toward the new weight', () {
      // Formula: T_new = T_old + 0.1 * (W_new - T_old)
      // T_Jan01 = 80.0  (seed)
      // T_Jan02 = 80.0 + 0.1 * (82.0 - 80.0) = 80.2
      final result = calculateTrend({
        '2026-01-01': 80.0,
        '2026-01-02': 82.0,
      });
      expectTrend(result, {
        '2026-01-01': 80.0,
        '2026-01-02': 80.2,
      });
    });

    test('gap day is filled in with a linearly interpolated virtual weight', () {
      // Jan01=80.0, Jan03=82.0 — Jan02 has no real entry.
      // Virtual weight for Jan02 = 80.0 + 0.5*(82.0-80.0) = 81.0
      // T_Jan02 = 80.0 + 0.1*(81.0-80.0) = 80.1  (virtual day)
      // T_Jan03 = 80.1 + 0.1*(82.0-80.1) = 80.29 (real day)
      final result = calculateTrend({
        '2026-01-01': 80.0,
        '2026-01-03': 82.0,
      });
      expectTrend(result, {
        '2026-01-01': 80.0,
        '2026-01-02': 80.1,
        '2026-01-03': 80.29,
      });
    });

    test('constant weight keeps the trend perfectly flat', () {
      // If every day's weight equals the trend, 0.1*(W-T) is always zero.
      final result = calculateTrend({
        '2026-01-01': 75.0,
        '2026-01-02': 75.0,
        '2026-01-03': 75.0,
      });
      expectTrend(result, {
        '2026-01-01': 75.0,
        '2026-01-02': 75.0,
        '2026-01-03': 75.0,
      });
    });

    test('trend lags behind a sudden weight drop', () {
      // The whole point of the exponential smoothing is that the trend does
      // NOT jump immediately — it only moves 10 % of the gap per day.
      // T_Jan01 = 80.0  (seed)
      // T_Jan02 = 80.0 + 0.1*(70.0-80.0) = 79.0  (moved only 1 kg, not 10)
      final result = calculateTrend({
        '2026-01-01': 80.0,
        '2026-01-02': 70.0,
      });
      expectTrend(result, {
        '2026-01-01': 80.0,
        '2026-01-02': 79.0,
      });
    });

    test('gap spanning a DST spring-forward day still counts calendar days correctly', () {
      // In Europe, clocks spring forward on the last Sunday of March.
      // 2024-03-31 is that day — it has only 23 hours in local time.
      // DateTime.difference() on local dates would return 7 days + 23 h,
      // which truncates to 7 (not 8), so showGap would be false and the EMA
      // would continue instead of restarting. Parsing as UTC avoids this.
      // 2024-03-31 → 2024-04-08 is 8 calendar days → must restart.
      final result = calculateTrend({
        '2024-03-31': 87.0,
        '2024-04-08': 89.0,
        '2024-04-09': 88.5,
      });
      // April 8 must equal the measured weight (restart), not an EMA carry-over.
      expect(result['2024-04-08'], closeTo(89.0, 1e-9),
          reason: 'EMA must restart at the new weight after an 8-day gap');
      // April 9 continues EMA from the restart value.
      // T = 89.0 + 0.1*(88.5 - 89.0) = 88.95
      expect(result['2024-04-09'], closeTo(88.95, 1e-9));
      // Gap days must not appear.
      for (int d = 1; d <= 7; d++) {
        expect(result.containsKey('2024-04-${d.toString().padLeft(2, '0')}'), false);
      }
    });

    test('gap longer than maxGapDays restarts trend at the new weight', () {
      // A 9-day gap (> 7) triggers a full restart: the trend at Jan10 resets
      // to the measured weight, exactly like the very first entry. The gap
      // days (Jan02–Jan09) are absent from the result. EMA then continues
      // normally from the restart value.
      // T_Jan01 = 80.0  (seed)
      // T_Jan10 = 79.0  (restart — equals the measured weight)
      // T_Jan11 = 79.0 + 0.1*(78.5 - 79.0) = 78.95
      final result = calculateTrend({
        '2026-01-01': 80.0,
        '2026-01-10': 79.0,
        '2026-01-11': 78.5,
      });
      expectTrend(result, {
        '2026-01-01': 80.0,
        '2026-01-10': 79.0,
        '2026-01-11': 78.95,
      });
      // Gap days must not appear in the result.
      for (int d = 2; d <= 9; d++) {
        final key = '2026-01-${d.toString().padLeft(2, '0')}';
        expect(result.containsKey(key), false, reason: '$key should be absent');
      }
    });
  });

  group('dateToString', () {
    test('formats a DateTime as YYYY-MM-DD', () {
      final dt = DateTime(2026, 6, 29);
      expect(dateToString(dt), '2026-06-29');
    });

    test('zero-pads single-digit months and days', () {
      expect(dateToString(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('stringToDate', () {
    test('parses YYYY-MM-DD back to midnight DateTime', () {
      final dt = stringToDate('2026-06-29');
      expect(dt, DateTime(2026, 6, 29));
    });
  });
}
