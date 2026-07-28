import 'package:drift/drift.dart';

import '../database.dart';

class OutlineDao extends DatabaseAccessor<AppDatabase> {
  OutlineDao(super.db);

  /// 获取某个章节的所有大纲节点
  Future<List<OutlineNode>> getOutlineNodesByChapter(String chapterId) async {
    return (select(db.outlineNodes)
          ..where((n) => n.chapterId.equals(chapterId))
          ..orderBy([(n) => OrderingTerm(expression: n.sortOrder)]))
        .get();
  }

  /// 获取某本书籍级大纲根节点（type='book_root'）
  Future<OutlineNode?> getBookRoot(String bookId) async {
    return (select(db.outlineNodes)
          ..where((n) => n.bookId.equals(bookId) & n.type.equals('book_root')))
        .getSingleOrNull();
  }

  /// 获取某本书所有书籍级大纲节点（chapterId 为空字符串的书籍级节点）
  Future<List<OutlineNode>> getOutlineByBook(String bookId) async {
    return (select(db.outlineNodes)
          ..where((n) => n.bookId.equals(bookId))
          ..orderBy([(n) => OrderingTerm(expression: n.sortOrder)]))
        .get();
  }

  /// 获取指定父节点下的所有子节点
  Future<List<OutlineNode>> getOutlineNodesByParent(String parentId) async {
    return (select(db.outlineNodes)
          ..where((n) => n.parentId.equals(parentId))
          ..orderBy([(n) => OrderingTerm(expression: n.sortOrder)]))
        .get();
  }

  /// 创建大纲节点
  Future<void> insertOutlineNode(OutlineNodesCompanion node) async {
    await into(db.outlineNodes).insert(node);
  }

  /// 批量创建大纲节点（事务）
  Future<void> insertOutlineNodes(List<OutlineNodesCompanion> nodes) async {
    await batch((b) {
      for (final node in nodes) {
        b.insert(db.outlineNodes, node);
      }
    });
  }

  /// 更新大纲节点
  Future<void> updateOutlineNode(OutlineNode node) async {
    await update(db.outlineNodes).replace(node);
  }

  /// 删除大纲节点
  Future<void> deleteOutlineNode(String id) async {
    await (delete(db.outlineNodes)..where((n) => n.id.equals(id))).go();
  }

  /// 删除某本书的所有书籍级大纲节点
  Future<void> deleteOutlineByBook(String bookId) async {
    await (delete(db.outlineNodes)..where((n) => n.bookId.equals(bookId))).go();
  }
}
