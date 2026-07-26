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
