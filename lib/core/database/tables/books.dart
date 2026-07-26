import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get cover => text().nullable()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  TextColumn get author => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ongoing'))();
  TextColumn get genre => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
