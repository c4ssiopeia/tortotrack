import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    this.onTap,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext; // null = already on current month (> shown disabled)
  final VoidCallback? onTap;  // opens the month/year picker

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(month);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: onTap != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            color: onNext == null ? Theme.of(context).disabledColor : null,
          ),
        ],
      ),
    );
  }
}

// Opens a compact year + month picker dialog.
// Calls [onSelected] with the chosen month as DateTime(year, month, 1).
Future<void> showMonthYearPicker(
  BuildContext context,
  DateTime current,
  void Function(DateTime) onSelected,
) async {
  final now = DateTime.now();
  int dialogYear = current.year;

  const shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setDialogState(() => dialogYear--),
              ),
              Text(
                dialogYear.toString(),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: dialogYear >= now.year
                    ? null
                    : () => setDialogState(() => dialogYear++),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                final now = DateTime.now();
                final currentMonth = DateTime(now.year, now.month);
                Navigator.of(ctx).pop();
                onSelected(currentMonth);
              },
              child: const Text('Today'),
            ),
          ],
          content: SizedBox(
            width: 240,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final monthNum = i + 1;
                final isFuture = dialogYear > now.year ||
                    (dialogYear == now.year && monthNum > now.month);
                final isSelected =
                    dialogYear == current.year && monthNum == current.month;
                return TextButton(
                  onPressed: isFuture
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          onSelected(DateTime(dialogYear, monthNum));
                        },
                  style: isSelected
                      ? TextButton.styleFrom(
                          backgroundColor:
                              Theme.of(ctx).colorScheme.primaryContainer,
                        )
                      : null,
                  child: Text(shortMonths[i]),
                );
              }),
            ),
          ),
        );
      },
    ),
  );
}
