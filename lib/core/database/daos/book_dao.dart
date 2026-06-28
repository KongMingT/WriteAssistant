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

  /// 删除书籍
  Future<void> deleteBook(String id) async {
    await (delete(db.books)..where((b) => b.id.equals(id))).go();
  }

  /// 获取书籍总字数
  Future<int> getBookWordCount(String bookId) async {
    final volumes = await (select(db.volumes)
          ..where((v) => v.bookId.equals(bookId)))
        .get();
    int total = 0;
    for (final vol in volumes) {
      final chapters = await (select(db.chapters)
            ..where((c) => c.volumeId.equals(vol.id)))
          .get();
      total += chapters.fold<int>(0, (sum, ch) => sum + ch.wordCount);
    }
    return total;
  }
}
