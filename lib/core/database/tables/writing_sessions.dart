import 'package:drift/drift.dart';

import 'books.dart';

class WritingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
