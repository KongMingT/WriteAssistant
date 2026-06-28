import 'package:drift/drift.dart';

import 'volumes.dart';

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get volumeId => text().references(Volumes, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
