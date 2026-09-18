import 'package:drift/drift.dart';

import '../database.dart';

/// 书籍相关数据访问
class BookDao extends DatabaseAccessor<AppDatabase> {
  BookDao(super.db);

  /// 获取所有书籍
  Future<List<Book>> getAllBooks() async {
    return select(db.books).get();
  }

  /// 按 ID 获取书籍
  Future<Book?> getBookById(String id) async {
    return (select(db.books)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// 创建书籍
  Future<void> insertBook(BooksCompanion book) async {
    await into(db.books).insert(book);
  }

  /// 更新书籍
  Future<void> updateBook(Book book) async {
    await update(db.books).replace(book);
  }

  /// 删除书籍（级联删除卷/章节/大纲/角色/关系/写作记录）
  Future<void> deleteBook(String id) async {
    await db.transaction(() async {
      final volumeIds = (await (db.select(db.volumes)..where((v) => v.bookId.equals(id))).get())
          .map((v) => v.id)
          .toList();

      var chapterIds = <String>[];
      for (final vid in volumeIds) {
        final chs = await (db.select(db.chapters)..where((c) => c.volumeId.equals(vid))).get();
        chapterIds.addAll(chs.map((c) => c.id));
      }

      // 大纲节点：先清章级（关联 chapterId），再清书籍级（关联 bookId）
      if (chapterIds.isNotEmpty) {
        await (db.delete(db.outlineNodes)..where((o) => o.chapterId.isIn(chapterIds))).go();
      }
      await (db.delete(db.outlineNodes)..where((o) => o.bookId.equals(id))).go();

      // 角色关系必须先于角色删除（外键引用 Characters）
      await (db.delete(db.characterRelations)..where((r) => r.bookId.equals(id))).go();
      await (db.delete(db.characters)..where((c) => c.bookId.equals(id))).go();

      // 写作记录
      await (db.delete(db.writingSessions)..where((s) => s.bookId.equals(id))).go();

      // 章节 → 卷 → 书籍
      if (volumeIds.isNotEmpty) {
        await (db.delete(db.chapters)..where((c) => c.volumeId.isIn(volumeIds))).go();
        await (db.delete(db.volumes)..where((v) => v.bookId.equals(id))).go();
      }
      await (db.delete(db.books)..where((b) => b.id.equals(id))).go();
    });
  }

  /// 重新计算并更新书籍字数（SQL SUM 聚合查询）
  Future<void> recalculateBookWordCount(String bookId) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(c.word_count), 0) AS total '
      'FROM chapters c '
      'INNER JOIN volumes v ON v.id = c.volume_id '
      'WHERE v.book_id = ?',
      variables: [Variable<String>(bookId)],
    ).getSingle();
    final total = result.data['total'] as int;
    await (update(db.books)..where((b) => b.id.equals(bookId)))
        .write(BooksCompanion(wordCount: Value(total)));
  }
}
