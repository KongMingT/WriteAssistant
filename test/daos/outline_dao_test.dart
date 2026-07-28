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

    // ===== 书籍级大纲方法测试 =====

    test('getBookRoot returns null when no root exists', () async {
      final root = await dao.getBookRoot(_bookId);
      expect(root, isNull);
    });

    test('getBookRoot returns the root node after insert', () async {
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('书籍大纲'),
        sortOrder: Value(0),
        type: const Value('book_root'),
      ));

      final root = await dao.getBookRoot(_bookId);
      expect(root, isNotNull);
      expect(root!.title, '书籍大纲');
      expect(root.type, 'book_root');
      expect(root.bookId, _bookId);
    });

    test('getOutlineByBook returns all book-level nodes', () async {
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('根节点'),
        sortOrder: Value(0),
        type: const Value('book_root'),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('第一卷'),
        sortOrder: Value(1),
        type: const Value('volume'),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('第二卷'),
        sortOrder: Value(2),
        type: const Value('volume'),
      ));

      final nodes = await dao.getOutlineByBook(_bookId);
      expect(nodes.length, 3);
      expect(nodes[0].title, '根节点');
      expect(nodes[1].title, '第一卷');
      expect(nodes[2].title, '第二卷');
    });

    test('getOutlineByBook returns empty for book with no nodes', () async {
      final nodes = await dao.getOutlineByBook('other-book');
      expect(nodes, isEmpty);
    });

    test('getOutlineNodesByParent returns children of a node', () async {
      final parentId = generateId();
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(parentId),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('第一卷'),
        sortOrder: Value(1),
        type: const Value('volume'),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        parentId: Value(parentId),
        title: Value('第一章'),
        sortOrder: Value(1),
        type: const Value('chapter'),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        parentId: Value(parentId),
        title: Value('第二章'),
        sortOrder: Value(2),
        type: const Value('chapter'),
      ));

      final children = await dao.getOutlineNodesByParent(parentId);
      expect(children.length, 2);
      expect(children[0].title, '第一章');
      expect(children[1].title, '第二章');
    });

    test('getOutlineNodesByParent returns empty for leaf node', () async {
      final children = await dao.getOutlineNodesByParent('nonexistent');
      expect(children, isEmpty);
    });

    test('insertOutlineNodes batch inserts', () async {
      final nodes = [
        OutlineNodesCompanion(
          id: Value(generateId()),
          bookId: Value(_bookId),
          chapterId: const Value(''),
          title: Value('Node 1'),
          sortOrder: Value(1),
        ),
        OutlineNodesCompanion(
          id: Value(generateId()),
          bookId: Value(_bookId),
          chapterId: const Value(''),
          title: Value('Node 2'),
          sortOrder: Value(2),
        ),
        OutlineNodesCompanion(
          id: Value(generateId()),
          bookId: Value(_bookId),
          chapterId: const Value(''),
          title: Value('Node 3'),
          sortOrder: Value(3),
        ),
      ];

      await dao.insertOutlineNodes(nodes);
      final allNodes = await dao.getOutlineByBook(_bookId);
      expect(allNodes.length, 3);
    });

    test('deleteOutlineByBook removes all book nodes', () async {
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('Keep'),
        sortOrder: Value(1),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('Also Keep'),
        sortOrder: Value(2),
      ));

      await dao.deleteOutlineByBook(_bookId);
      final nodes = await dao.getOutlineByBook(_bookId);
      expect(nodes, isEmpty);
    });

    test('deleteOutlineByBook does not affect other books', () async {
      const otherBook = 'other-test-book';
      await db.into(db.books).insert(BooksCompanion(
        id: Value(otherBook),
        title: Value('Other Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        chapterId: const Value(''),
        title: Value('Book1 Node'),
        sortOrder: Value(1),
      ));
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(otherBook),
        chapterId: const Value(''),
        title: Value('Other Node'),
        sortOrder: Value(1),
      ));

      await dao.deleteOutlineByBook(_bookId);

      final book1Nodes = await dao.getOutlineByBook(_bookId);
      expect(book1Nodes, isEmpty);
      final otherNodes = await dao.getOutlineByBook(otherBook);
      expect(otherNodes.length, 1);
    });
  });
}
