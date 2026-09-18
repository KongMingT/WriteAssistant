import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/book_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

void main() {
  late AppDatabase db;
  late BookDao dao;

  setUp(() {
    db = createTestDb();
    dao = BookDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BookDao', () {
    test('insert and get all books', () async {
      await dao.insertBook(BooksCompanion(
        id: Value(generateId()),
        title: Value('Test Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final books = await dao.getAllBooks();
      expect(books.length, 1);
      expect(books.first.title, 'Test Book');
    });

    test('get book by id returns null for nonexistent', () async {
      final book = await dao.getBookById('nonexistent');
      expect(book, isNull);
    });

    test('update book', () async {
      final id = generateId();
      await dao.insertBook(BooksCompanion(
        id: Value(id),
        title: Value('Original'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final book = await dao.getBookById(id);
      await dao.updateBook(book!.copyWith(title: 'Updated'));

      final updated = await dao.getBookById(id);
      expect(updated!.title, 'Updated');
    });

    test('delete book', () async {
      final id = generateId();
      await dao.insertBook(BooksCompanion(
        id: Value(id),
        title: Value('To Delete'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.deleteBook(id);
      final books = await dao.getAllBooks();
      expect(books, isEmpty);
    });

    test('delete book cascades volumes/chapters/outline/characters/sessions', () async {
      final bookId = generateId();
      await dao.insertBook(BooksCompanion(
        id: Value(bookId),
        title: Value('Cascade'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final volumeId = generateId();
      await db.into(db.volumes).insert(VolumesCompanion(
        id: Value(volumeId),
        bookId: Value(bookId),
        title: Value('V1'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      final chapterId = generateId();
      await db.into(db.chapters).insert(ChaptersCompanion(
        id: Value(chapterId),
        volumeId: Value(volumeId),
        title: Value('Ch1'),
        content: Value('abcdefg'),
        wordCount: Value(7),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      // 书籍级 + 章级大纲节点
      await db.into(db.outlineNodes).insert(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        chapterId: const Value(''),
        title: const Value('book outline'),
        sortOrder: const Value(1),
        type: const Value('book_root'),
      ));
      await db.into(db.outlineNodes).insert(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        chapterId: Value(chapterId),
        title: const Value('chapter outline'),
        sortOrder: const Value(1),
        type: const Value('chapter_summary'),
      ));

      // 角色 + 关系
      final characterId = generateId();
      await db.into(db.characters).insert(CharactersCompanion(
        id: Value(characterId),
        bookId: Value(bookId),
        name: const Value('Hero'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      await db.into(db.characterRelations).insert(CharacterRelationsCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        characterAId: Value(characterId),
        characterBId: Value(characterId),
        relationType: const Value('self'),
      ));

      // 写作记录
      await db.into(db.writingSessions).insert(WritingSessionsCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        chapterId: Value(chapterId),
        startTime: Value(DateTime.now()),
      ));

      await dao.deleteBook(bookId);

      expect(await dao.getAllBooks(), isEmpty);
      expect(await db.select(db.volumes).get(), isEmpty);
      expect(await db.select(db.chapters).get(), isEmpty);
      expect(await db.select(db.outlineNodes).get(), isEmpty);
      expect(await db.select(db.characters).get(), isEmpty);
      expect(await db.select(db.characterRelations).get(), isEmpty);
      expect(await db.select(db.writingSessions).get(), isEmpty);
    });

    test('recalculate word count from chapters', () async {
      final bookId = generateId();
      await dao.insertBook(BooksCompanion(
        id: Value(bookId),
        title: Value('WCTest'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final volumeId = generateId();
      await db.into(db.volumes).insert(VolumesCompanion(
        id: Value(volumeId),
        bookId: Value(bookId),
        title: Value('V1'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      await db.into(db.chapters).insert(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: Value(volumeId),
        title: Value('Ch1'),
        content: Value('Hello World'),
        wordCount: Value(11),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await db.into(db.chapters).insert(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: Value(volumeId),
        title: Value('Ch2'),
        content: Value('Short'),
        wordCount: Value(5),
        sortOrder: Value(2),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.recalculateBookWordCount(bookId);
      final book = await dao.getBookById(bookId);
      expect(book!.wordCount, 16);
    });
  });
}
