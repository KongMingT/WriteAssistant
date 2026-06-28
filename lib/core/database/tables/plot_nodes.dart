import 'package:drift/drift.dart';

import 'chapters.dart';
import 'plot_lines.dart';

class PlotNodes extends Table {
  TextColumn get id => text()();
  TextColumn get plotLineId => text().references(PlotLines, #id)();
  TextColumn get chapterId => text().references(Chapters, #id).nullable()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
