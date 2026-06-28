import 'package:drift/drift.dart';

import 'books.dart';

class Volumes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
