import '../main.dart';

// Formats a plain number to a fixed number of decimals, using either '.' or
// ',' depending on the user's decimal-separator preference. Display only —
// CSV export always uses '.' so files stay machine-readable regardless of
// this setting.
String formatNumber(double value, {int decimals = 2}) {
  final s = value.toStringAsFixed(decimals);
  return decimalSeparatorNotifier.value == DecimalSeparator.comma
      ? s.replaceAll('.', ',')
      : s;
}

String formatWeight(double kg, bool useLbs, {int decimals = 2}) {
  final value = useLbs ? kg * 2.20462 : kg;
  final unit = useLbs ? 'lbs' : 'kg';
  return '${formatNumber(value, decimals: decimals)} $unit';
}
