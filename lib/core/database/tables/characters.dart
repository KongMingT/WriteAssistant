import 'package:drift/drift.dart';

import 'books.dart';

class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get name => text()();
  TextColumn get gender => text().nullable()();
  TextColumn get age => text().nullable()();
  TextColumn get personality => text().nullable()();
  TextColumn get background => text().nullable()();
  TextColumn get appearance => text().nullable()();
  TextColumn get roleType => text().withDefault(const Constant('supporting'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
