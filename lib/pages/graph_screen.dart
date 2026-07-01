import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../database/weight_entry.dart';
import '../main.dart';
import '../src/month_header.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  @override
  void initState() {
    super.initState();
    monthNotifier.addListener(_onMonthChanged);
  }

  @override
  void dispose() {
    monthNotifier.removeListener(_onMonthChanged);
    super.dispose();
  }

  void _onMonthChanged() => setState(() {});

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return monthNotifier.value.year == now.year &&
        monthNotifier.value.month == now.month;
  }

  void _prevMonth() {
    final m = monthNotifier.value;
    monthNotifier.value = DateTime(m.year, m.month - 1);
  }

  void _nextMonth() {
    if (!_isCurrentMonth) {
      final m = monthNotifier.value;
      monthNotifier.value = DateTime(m.year, m.month + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weightColor = isDark ? Colors.blue[300]! : Colors.blue[700]!;
    final trendColor = isDark ? Colors.orange[300]! : Colors.deepOrange;

    return ValueListenableBuilder<WeightGoal>(
      valueListenable: goalNotifier,
      builder: (context, goal, _) => ValueListenableBuilder<bool>(
        valueListenable: useLbsNotifier,
        builder: (context, useLbs, _) => StreamBuilder<List<WeightEntry>>(
        stream: db.watchAllEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final current = monthNotifier.value;
          final allEntries = snapshot.data ?? [];
          final allMap = {for (final e in allEntries) e.date: e.weightKg};
          final trendMap = calculateTrend(allMap);
          final prefix = DateFormat('yyyy-MM').format(current);
          final unit = useLbs ? 'lbs' : 'kg';

          final weightSpots = allEntries
              .where((e) => e.date.startsWith(prefix))
              .map((e) => FlSpot(
                    DateTime.parse(e.date).day.toDouble(),
                    _convert(e.weightKg, useLbs),
                  ))
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));

          // Split the trend into continuous segments. Each gap (day missing from
          // trendMap) ends the current segment. Segments with only 1 point are
          // dropped — a single isolated dot at the restart position is redundant
          // with the blue weight dot and causes bezier artefacts in fl_chart.
          final lastDay = DateTime(current.year, current.month + 1, 0).day;
          // Build segments from real entry days only. Virtual gap days contribute
          // to the EMA calculation but are not rendered — the line visits only
          // days where the user actually recorded a weight. A missing trendMap
          // value (long gap / restart) ends the segment; a virtual day is
          // silently skipped without breaking the segment.
          final trendSegments = <List<FlSpot>>[];
          List<FlSpot>? seg;
          for (int day = 1; day <= lastDay; day++) {
            final dateStr = DateFormat('yyyy-MM-dd')
                .format(DateTime(current.year, current.month, day));
            final val = trendMap[dateStr];
            final isReal = allMap.containsKey(dateStr);
            if (val == null) {
              if (seg != null) {
                if (seg.length >= 2) trendSegments.add(seg);
                seg = null;
              }
            } else if (isReal) {
              seg ??= [];
              seg.add(FlSpot(day.toDouble(), _convert(val, useLbs)));
            }
            // Virtual interpolated day: skip (don't add, don't break).
          }
          if (seg != null && seg.length >= 2) trendSegments.add(seg);

          final trendBars = trendSegments
              .map((spots) => LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: trendColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ))
              .toList();
          final numTrendBars = trendBars.length;

          // Build day→trendY lookup from all segments for drop lines.
          final trendByDay = <double, double>{
            for (final s in trendSegments.expand((s) => s)) s.x: s.y,
          };
          final dropLineBars = <LineChartBarData>[];
          for (final ws in weightSpots) {
            final trendY = trendByDay[ws.x];
            if (trendY == null) continue;
            // Skip zero-length drop lines (trend == weight at EMA restart point).
            if ((trendY - ws.y).abs() < 0.01) continue;
            final dayDate =
                DateTime(current.year, current.month, ws.x.toInt());
            final todayStr =
                DateFormat('yyyy-MM-dd').format(dayDate);
            final prevStr = DateFormat('yyyy-MM-dd')
                .format(dayDate.subtract(const Duration(days: 1)));
            final lineColor = goalColor(
              currentTrend: trendMap[todayStr],
              previousTrend: trendMap[prevStr],
              goal: goal,
              isDark: isDark,
            );
            dropLineBars.add(LineChartBarData(
              spots: [FlSpot(ws.x, trendY), FlSpot(ws.x, ws.y)],
              isCurved: false,
              color: lineColor.withValues(alpha: 0.8),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ));
          }

          final rateText = _rateText(trendMap, prefix, useLbs, unit);

          final allY = [
            ...weightSpots.map((s) => s.y),
            ...trendSegments.expand((s) => s).map((s) => s.y),
          ];

          return Column(
            children: [
              MonthHeader(
                month: current,
                onPrev: _prevMonth,
                onNext: _isCurrentMonth ? null : _nextMonth,
                onTap: () => showMonthYearPicker(
                  context,
                  current,
                  (dt) => monthNotifier.value = dt,
                ),
              ),
              if (rateText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    rateText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: allEntries.isEmpty
                    ? const Center(
                        child: Text(
                          'No data yet.\nAdd weights in the List tab.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : weightSpots.isEmpty && trendSegments.isEmpty
                        ? const Center(child: Text('No data for this month.'))
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
                            child: LineChart(
                              LineChartData(
                                minX: 1,
                                maxX: lastDay.toDouble(),
                                minY: allY.reduce((a, b) => a < b ? a : b) -
                                    (useLbs ? 2 : 1),
                                maxY: allY.reduce((a, b) => a > b ? a : b) +
                                    (useLbs ? 2 : 1),
                                clipData: const FlClipData.all(),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (_) => FlLine(
                                    color: Theme.of(context).dividerColor,
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 52,
                                      getTitlesWidget: (value, meta) {
                                        if (value == meta.min ||
                                            value == meta.max) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                          value.toStringAsFixed(1),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 7,
                                      getTitlesWidget: (value, meta) => Text(
                                        value.toInt().toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                  ),
                                ),
                                lineTouchData: LineTouchData(
                                  getTouchedSpotIndicator:
                                      (barData, spotIndexes) {
                                    // No tap indicator dots/lines on any bar —
                                    // the tooltip bubble is enough on Android.
                                    return spotIndexes
                                        .map((_) => null)
                                        .toList();
                                  },
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (_) => Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    getTooltipItems: (spots) =>
                                        spots.map((spot) {
                                      // Layout: 0..numTrendBars-1 = trend segments,
                                      // numTrendBars = weight, beyond = drop lines.
                                      if (spot.barIndex > numTrendBars) return null;
                                      final isTrend = spot.barIndex < numTrendBars;
                                      return LineTooltipItem(
                                        '${isTrend ? 'Trend' : 'Weight'}: '
                                        '${spot.y.toStringAsFixed(1)} $unit',
                                        TextStyle(
                                          color: isTrend
                                              ? trendColor
                                              : weightColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                lineBarsData: [
                                  // 0..numTrendBars-1: trend segments
                                  ...trendBars,
                                  // numTrendBars: weight dots — no connecting line
                                  LineChartBarData(
                                    spots: weightSpots,
                                    isCurved: false,
                                    color: weightColor,
                                    barWidth: 0,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (_, __, ___, ____) =>
                                          FlDotCirclePainter(
                                        radius: 4,
                                        color: weightColor,
                                        strokeWidth: 2,
                                        strokeColor: isDark
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // numTrendBars+1+: vertical sticks
                                  ...dropLineBars,
                                ],
                              ),
                            ),
                          ),
              ),
              _Legend(weightColor: weightColor, trendColor: trendColor),
            ],
          );
        },
        ),
      ),
    );
  }
}

double _convert(double kg, bool useLbs) => useLbs ? kg * 2.20462 : kg;

String? _rateText(
    Map<String, double> trendMap, String prefix, bool useLbs, String unit) {
  final monthTrend = trendMap.entries
      .where((e) => e.key.startsWith(prefix))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (monthTrend.length < 2) return null;

  final first = monthTrend.first.value;
  final last = monthTrend.last.value;
  final days = DateTime.parse(monthTrend.last.key)
      .difference(DateTime.parse(monthTrend.first.key))
      .inDays;
  if (days == 0) return null;

  final totalChange = _convert(last - first, useLbs);
  final perWeek = totalChange / days * 7;
  final sign = totalChange >= 0 ? '+' : '';
  final signW = perWeek >= 0 ? '+' : '';

  return 'This month: $sign${totalChange.toStringAsFixed(1)} $unit  '
      '($signW${perWeek.toStringAsFixed(2)} $unit/week)';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.weightColor, required this.trendColor});
  final Color weightColor;
  final Color trendColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Dot(color: weightColor),
          const SizedBox(width: 6),
          const Text('Weight'),
          const SizedBox(width: 20),
          _Dot(color: trendColor),
          const SizedBox(width: 6),
          const Text('Trend (EMA)'),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
