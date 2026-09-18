import 'package:drift/drift.dart';

import '../database.dart';

/// 章节版本快照数据访问
class SnapshotDao extends DatabaseAccessor<AppDatabase> {
  SnapshotDao(super.db);

  /// 记录某章节保存前的快照
  Future<void> createSnapshot(String chapterId, String title, String content) async {
    await into(db.chapterSnapshots).insert(ChapterSnapshotsCompanion.insert(
      chapterId: chapterId,
      title: title,
      content: content,
      createdAt: DateTime.now(),
    ));
  }

  /// 读取某章节的历史快照（新→旧）
  Future<List<ChapterSnapshot>> getSnapshots(String chapterId) async {
    return (select(db.chapterSnapshots)
          ..where((s) => s.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.desc(t.seq)]))
        .get();
  }

  /// 删除某章节的所有快照
  Future<void> deleteSnapshotsByChapter(String chapterId) async {
    await (delete(db.chapterSnapshots)..where((s) => s.chapterId.equals(chapterId))).go();
  }
}