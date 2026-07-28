import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/outline_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'outline-test-book';
const _volumeId = 'outline-test-volume';
const _chapterId = 'outline-test-chapter';

Future<void> _seed(AppDatabase db) async {
  await db.into(db.books).insert(BooksCompanion(
        id: Value(_bookId),
        title: Value('Test Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
  await db.into(db.volumes).insert(VolumesCompanion(
        id: Value(_volumeId),
        bookId: Value(_bookId),
        title: Value('V1'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));
  await db.into(db.chapters).insert(ChaptersCompanion(
        id: Value(_chapterId),
        volumeId: Value(_volumeId),
        title: Value('Ch1'),
        content: Value(''),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
}

void main() {
  late AppDatabase db;
  late OutlineDao dao;

  setUp(() async {
    db = createTestDb();
    await _seed(db);
    dao = OutlineDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('OutlineDao', () {
    test('insert and get nodes by chapter', () async {
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        chapterId: Value(_chapterId),
        title: Value('章纲1'),
        sortOrder: Value(1),
      ));

      final nodes = await dao.getOutlineNodesByChapter(_chapterId);
      expect(nodes.length, 1);
      expect(nodes.first.title, '章纲1');
    });

    test('get nodes ordered by sortOrder', () async {
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        chapterId: Value(_chapterId),
        title: Value('Node B'),
        sortOrder: Value(2),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        chapterId: Value(_chapterId),
        title: Value('Node A'),
        sortOrder: Value(1),
      ));

      final nodes = await dao.getOutlineNodesByChapter(_chapterId);
      expect(nodes.length, 2);
      expect(nodes[0].title, 'Node A');
      expect(nodes[1].title, 'Node B');
    });

    test('update outline node', () async {
      final id = generateId();
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(id),
        chapterId: Value(_chapterId),
        title: Value('Original'),
        sortOrder: Value(1),
      ));

      final node = await dao.getOutlineNodesByChapter(_chapterId);
      await dao.updateOutlineNode(node.first.copyWith(title: 'Updated'));

      final nodes = await dao.getOutlineNodesByChapter(_chapterId);
      expect(nodes.first.title, 'Updated');
    });

    test('delete outline node', () async {
      final id = generateId();
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(id),
        chapterId: Value(_chapterId),
        title: Value('To Delete'),
        sortOrder: Value(1),
      ));

      await dao.deleteOutlineNode(id);
      final nodes = await dao.getOutlineNodesByChapter(_chapterId);
      expect(nodes, isEmpty);
    });
  });
}
