import 'package:drift/drift.dart';

import 'chapters.dart';

class OutlineNodes extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text().references(Chapters, #id)();
  TextColumn get parentId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get type => text().withDefault(const Constant('outline'))();

  @override
  Set<Column> get primaryKey => {id};
}
