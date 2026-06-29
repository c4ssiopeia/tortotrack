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
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.year == now.year && _currentMonth.month == now.month;
  }

  void _prevMonth() => setState(
      () => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));

  void _nextMonth() {
    if (!_isCurrentMonth) {
      setState(() =>
          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weightColor = isDark ? Colors.blue[300]! : Colors.blue[700]!;
    final trendColor = isDark ? Colors.orange[300]! : Colors.deepOrange;

    return ValueListenableBuilder<bool>(
      valueListenable: useLbsNotifier,
      builder: (context, useLbs, _) => StreamBuilder<List<WeightEntry>>(
        stream: db.watchAllEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snapshot.data ?? [];
          final allMap = {for (final e in allEntries) e.date: e.weightKg};
          final trendMap = calculateTrend(allMap);
          final prefix = DateFormat('yyyy-MM').format(_currentMonth);
          final unit = useLbs ? 'lbs' : 'kg';

          final weightSpots = allEntries
              .where((e) => e.date.startsWith(prefix))
              .map((e) => FlSpot(
                    DateTime.parse(e.date).day.toDouble(),
                    _convert(e.weightKg, useLbs),
                  ))
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));

          final trendSpots = trendMap.entries
              .where((e) => e.key.startsWith(prefix))
              .map((e) => FlSpot(
                    DateTime.parse(e.key).day.toDouble(),
                    _convert(e.value, useLbs),
                  ))
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));

          final rateText = _rateText(trendMap, prefix, useLbs, unit);

          final allY = [
            ...weightSpots.map((s) => s.y),
            ...trendSpots.map((s) => s.y),
          ];
          final lastDay =
              DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

          return Column(
            children: [
              MonthHeader(
                month: _currentMonth,
                onPrev: _prevMonth,
                onNext: _isCurrentMonth ? null : _nextMonth,
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
                    : weightSpots.isEmpty && trendSpots.isEmpty
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
                                      sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false)),
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
                                          '${value.toStringAsFixed(1)}',
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
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (_) => Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    getTooltipItems: (spots) =>
                                        spots.map((spot) {
                                      final isTrend = spot.barIndex == 0;
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
                                  LineChartBarData(
                                    spots: trendSpots,
                                    isCurved: true,
                                    curveSmoothness: 0.25,
                                    color: trendColor,
                                    barWidth: 2.5,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  LineChartBarData(
                                    spots: weightSpots,
                                    isCurved: false,
                                    color: weightColor,
                                    barWidth: 1.5,
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
    );
  }
}

double _convert(double kg, bool useLbs) => useLbs ? kg * 2.20462 : kg;

// Returns a human-readable summary of how the trend moved this month.
// Returns null if there are fewer than 2 trend points in the month.
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
