import 'package:drift/drift.dart';

import '../database.dart';

class ChapterDao extends DatabaseAccessor<AppDatabase> {
  ChapterDao(super.db);

  /// 获取某个卷的所有章节（按排序）
  Future<List<Chapter>> getChaptersByVolume(String volumeId) async {
    return (select(db.chapters)
          ..where((c) => c.volumeId.equals(volumeId))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  /// 按 ID 获取章节
  Future<Chapter?> getChapterById(String id) async {
    return (select(db.chapters)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// 创建章节
  Future<void> insertChapter(ChaptersCompanion chapter) async {
    await into(db.chapters).insert(chapter);
  }

  /// 更新章节内容
  Future<void> updateChapterContent(String id, String content) async {
    await (update(db.chapters)..where((c) => c.id.equals(id))).write(
      ChaptersCompanion(
        content: Value(content),
        wordCount: Value(content.length),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新章节标题
  Future<void> updateChapterTitle(String id, String title) async {
    await (update(db.chapters)..where((c) => c.id.equals(id))).write(
      ChaptersCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 更新章节
  Future<void> updateChapter(Chapter chapter) async {
    await update(db.chapters).replace(chapter);
  }

  /// 删除章节
  Future<void> deleteChapter(String id) async {
    await (delete(db.chapters)..where((c) => c.id.equals(id))).go();
  }
}
