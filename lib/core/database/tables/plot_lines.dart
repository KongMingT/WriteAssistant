import 'package:drift/drift.dart';

import 'books.dart';

class PlotLines extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get title => text()();
  TextColumn get type => text().withDefault(const Constant('main'))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
