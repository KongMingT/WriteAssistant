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
