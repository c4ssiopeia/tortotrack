// import 'package:drift/drift.dart';
// import 'dart:io';
// import 'package:drift/native.dart';
// part 'weight_entry.g.dart';
// import 'package:intl/intl.dart'; // formatting datetime to string

// @DataClassName('WeightEntry')
// class WeightEntries extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get date => text()();
//   RealColumn get weight => real()();
// }

// @DriftDatabase(tables: [WeightEntries])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

//   @override
//   int get schemaVersion => 1;

//   static QueryExecutor _openConnection() {
//     return NativeDatabase.createInBackground(File('../weights.db'));
//   }
// }

// String dateToString(DateTime dateTime) {
//   final DateFormat formatter = DateFormat('yyyy-MM-dd');
//   final String stringDate = formatter.format(dateTime);
//   return stringDate;
// }

// // replacing , with . to format userinput to double and throw an error when not entering the right foramt
// double correctWeightToDouble(String weightInput) {
//   try {
//     return double.parse(weightInput.replaceAll(",", "."));
//   } catch (e) {
//     print("You didn't input a number. Please input Numbers like '100,00' or '98.95' or '80'!");
//     exit(1);
//   }
// }