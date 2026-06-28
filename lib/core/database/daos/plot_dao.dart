import 'package:drift/drift.dart';

import '../database.dart';

class PlotDao extends DatabaseAccessor<AppDatabase> {
  PlotDao(super.db);

  // ===== 剧情线 =====

  /// 获取某本书的所有剧情线
  Future<List<PlotLine>> getPlotLinesByBook(String bookId) async {
    return (select(db.plotLines)..where((p) => p.bookId.equals(bookId)))
        .get();
  }

  /// 创建剧情线
  Future<void> insertPlotLine(PlotLinesCompanion plotLine) async {
    await into(db.plotLines).insert(plotLine);
  }

  /// 删除剧情线
  Future<void> deletePlotLine(String id) async {
    await (delete(db.plotLines)..where((p) => p.id.equals(id))).go();
  }

  // ===== 剧情节点 =====

  /// 获取某个剧情线下的所有节点
  Future<List<PlotNode>> getPlotNodesByLine(String plotLineId) async {
    return (select(db.plotNodes)
          ..where((n) => n.plotLineId.equals(plotLineId))
          ..orderBy([(n) => OrderingTerm(expression: n.sortOrder)]))
        .get();
  }

  /// 创建剧情节点
  Future<void> insertPlotNode(PlotNodesCompanion node) async {
    await into(db.plotNodes).insert(node);
  }

  /// 删除剧情节点
  Future<void> deletePlotNode(String id) async {
    await (delete(db.plotNodes)..where((n) => n.id.equals(id))).go();
  }
}
