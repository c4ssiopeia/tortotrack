import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../database/weight_entry.dart';
import '../main.dart';
import '../src/month_header.dart';

String _formatWeight(double kg, bool useLbs) {
  if (useLbs) return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
  return '${kg.toStringAsFixed(1)} kg';
}

String _unitLabel(bool useLbs) => useLbs ? 'lbs' : 'kg';

double _toKg(double value, bool useLbs) =>
    useLbs ? value / 2.20462 : value;

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    monthNotifier.addListener(_onMonthChanged);
  }

  @override
  void dispose() {
    monthNotifier.removeListener(_onMonthChanged);
    _weightController.dispose();
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

  // Returns all days of the current month up to and including today.
  // Future dates are excluded so today always sits at the top of the list.
  List<DateTime> _visibleDays() {
    final m = monthNotifier.value;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDay = DateTime(m.year, m.month + 1, 0).day;
    return List.generate(lastDay, (i) => DateTime(m.year, m.month, i + 1))
        .where((d) => !d.isAfter(todayDate))
        .toList();
  }

  Widget _weightField(bool useLbs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Weight in ${_unitLabel(useLbs)}',
            errorMaxLines: 3,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a weight.';
            if (double.tryParse(value.replaceAll(',', '.')) == null) {
              return "Enter a number like '100.00', '98,95' or '80'.";
            }
            return null;
          },
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context, DateTime date,
      double? existingWeightKg) {
    final useLbs = useLbsNotifier.value;
    if (existingWeightKg != null) {
      final display = useLbs
          ? existingWeightKg * 2.20462
          : existingWeightKg;
      _weightController.text = display.toStringAsFixed(1);
    } else {
      _weightController.clear();
    }
    final label = DateFormat('EEE, MMM d, y').format(date);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          _weightField(useLbs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  _weightController.clear();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final entered = double.parse(
                        _weightController.text.replaceAll(',', '.'));
                    final kg = _toKg(entered, useLbs);
                    await db.upsertEntry(dateToString(date), kg);
                    _weightController.clear();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WeightGoal>(
      valueListenable: goalNotifier,
      builder: (context, goal, _) => ValueListenableBuilder<bool>(
        valueListenable: useLbsNotifier,
        builder: (context, useLbs, _) => _buildBody(context, useLbs, goal),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool useLbs, WeightGoal goal) {
    final current = monthNotifier.value;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final today = DateTime.now();
          final existing = await db.getEntryForDate(dateToString(today));
          if (context.mounted) _showDialog(context, today, existing?.weightKg);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
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
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<WeightEntry>>(
              stream: db.watchAllEntries(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allEntries = snapshot.data ?? [];
                final allMap = {for (final e in allEntries) e.date: e.weightKg};
                final (:trend, :estimates) =
                    calculateTrendWithEstimates(allMap);
                final trendMap = trend;
                final prefix = DateFormat('yyyy-MM').format(current);
                final entryMap = {
                  for (final e in allEntries)
                    if (e.date.startsWith(prefix)) e.date: e.weightKg,
                };
                final days = _visibleDays().reversed.toList();
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final dateStr = dateToString(day);
                    final weight = entryMap[dateStr];
                    final label = DateFormat('EEE, MMM d').format(day);
                    final isFuture = day.isAfter(DateTime.now());
                    final isWeekend = day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final weekendColor = isWeekend
                        ? (isDark ? Colors.grey[800] : Colors.grey[200])
                        : null;

                    final trendKg = trendMap[dateStr];
                    final prevDateStr =
                        dateToString(day.subtract(const Duration(days: 1)));
                    final prevTrendKg = trendMap[prevDateStr];
                    final trendColor = isDark
                        ? Colors.orange[300]!
                        : Colors.deepOrange;

                    if (weight != null) {
                      final trendDisplayColor = goalColor(
                        currentTrend: trendKg,
                        previousTrend: prevTrendKg,
                        goal: goal,
                        isDark: isDark,
                      );
                      return Dismissible(
                        key: ValueKey(dateStr),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: Text('Remove the entry for $label?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                        onDismissed: (_) => db.deleteEntry(dateStr),
                        child: ListTile(
                          tileColor: weekendColor,
                          title: Row(
                            children: [
                              Text(label),
                              if (trendKg != null) ...[
                                const Spacer(),
                                Text(
                                  'trend ${_formatWeight(trendKg, useLbs)}',
                                  style: TextStyle(
                                    color: trendDisplayColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Text(
                            _formatWeight(weight, useLbs),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          onTap: () => _showDialog(context, day, weight),
                        ),
                      );
                    }

                    // Empty day — show an interpolated estimate in the title
                    // row when one exists, alongside the + icon so the user
                    // knows they can still add a real weight.
                    final estimateKg = estimates[dateStr];
                    return ListTile(
                      tileColor: weekendColor,
                      title: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isFuture
                                  ? Theme.of(context).disabledColor
                                  : null,
                            ),
                          ),
                          if (estimateKg != null && !isFuture) ...[
                            const Spacer(),
                            Text(
                              '~${_formatWeight(estimateKg, useLbs)}',
                              style: TextStyle(
                                color: trendColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isFuture
                          ? null
                          : Icon(Icons.add,
                              color: Theme.of(context).disabledColor),
                      onTap: isFuture
                          ? null
                          : () => _showDialog(context, day, null),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

