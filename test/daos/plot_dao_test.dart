import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/plot_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'plot-test-book';

Future<void> _seedBook(AppDatabase db) async {
  await db.into(db.books).insert(BooksCompanion(
        id: Value(_bookId),
        title: Value('Test Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
}

void main() {
  late AppDatabase db;
  late PlotDao dao;

  setUp(() async {
    db = createTestDb();
    await _seedBook(db);
    dao = PlotDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PlotDao', () {
    test('insert and get plot lines by book', () async {
      await dao.insertPlotLine(PlotLinesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        title: Value('主线'),
        sortOrder: Value(1),
      ));

      final lines = await dao.getPlotLinesByBook(_bookId);
      expect(lines.length, 1);
      expect(lines.first.title, '主线');
    });

    test('delete plot line', () async {
      final id = generateId();
      await dao.insertPlotLine(PlotLinesCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        title: Value('To Delete'),
        sortOrder: Value(1),
      ));

      await dao.deletePlotLine(id);
      final lines = await dao.getPlotLinesByBook(_bookId);
      expect(lines, isEmpty);
    });

    test('insert and get plot nodes by line', () async {
      final lineId = generateId();
      await dao.insertPlotLine(PlotLinesCompanion(
        id: Value(lineId),
        bookId: Value(_bookId),
        title: Value('Line'),
        sortOrder: Value(1),
      ));

      await dao.insertPlotNode(PlotNodesCompanion(
        id: Value(generateId()),
        plotLineId: Value(lineId),
        title: Value('Node 1'),
        sortOrder: Value(1),
      ));

      final nodes = await dao.getPlotNodesByLine(lineId);
      expect(nodes.length, 1);
      expect(nodes.first.title, 'Node 1');
    });

    test('get plot nodes ordered by sortOrder', () async {
      final lineId = generateId();
      await dao.insertPlotLine(PlotLinesCompanion(
        id: Value(lineId),
        bookId: Value(_bookId),
        title: Value('Line'),
        sortOrder: Value(1),
      ));

      await dao.insertPlotNode(PlotNodesCompanion(
        id: Value(generateId()),
        plotLineId: Value(lineId),
        title: Value('B'),
        sortOrder: Value(2),
      ));
      await dao.insertPlotNode(PlotNodesCompanion(
        id: Value(generateId()),
        plotLineId: Value(lineId),
        title: Value('A'),
        sortOrder: Value(1),
      ));

      final nodes = await dao.getPlotNodesByLine(lineId);
      expect(nodes.length, 2);
      expect(nodes[0].title, 'A');
      expect(nodes[1].title, 'B');
    });

    test('delete plot node', () async {
      final lineId = generateId();
      await dao.insertPlotLine(PlotLinesCompanion(
        id: Value(lineId),
        bookId: Value(_bookId),
        title: Value('Line'),
        sortOrder: Value(1),
      ));

      final nodeId = generateId();
      await dao.insertPlotNode(PlotNodesCompanion(
        id: Value(nodeId),
        plotLineId: Value(lineId),
        title: Value('To Delete'),
        sortOrder: Value(1),
      ));

      await dao.deletePlotNode(nodeId);
      final nodes = await dao.getPlotNodesByLine(lineId);
      expect(nodes, isEmpty);
    });
  });
}
