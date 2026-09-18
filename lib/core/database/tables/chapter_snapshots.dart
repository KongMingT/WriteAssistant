import 'package:drift/drift.dart';

import 'chapters.dart';

/// 章节版本快照（每次保存前记录上一版本，可回退）
class ChapterSnapshots extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get chapterId => text().references(Chapters, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {seq};
}