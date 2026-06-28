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

  /// 创建大纲节点
  Future<void> insertOutlineNode(OutlineNodesCompanion node) async {
    await into(db.outlineNodes).insert(node);
  }

  /// 更新大纲节点
  Future<void> updateOutlineNode(OutlineNode node) async {
    await update(db.outlineNodes).replace(node);
  }

  /// 删除大纲节点
  Future<void> deleteOutlineNode(String id) async {
    await (delete(db.outlineNodes)..where((n) => n.id.equals(id))).go();
  }
}
