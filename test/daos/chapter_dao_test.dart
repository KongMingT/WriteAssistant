import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/chapter_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'chapter-test-book';
const _volumeId = 'chapter-test-volume';

Future<void> _seedBookAndVolume(AppDatabase db) async {
  await db.into(db.books).insert(BooksCompanion(
        id: const Value(_bookId),
        title: const Value('Test Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
  await db.into(db.volumes).insert(VolumesCompanion(
        id: const Value(_volumeId),
        bookId: const Value(_bookId),
        title: const Value('V1'),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
      ));
}

void main() {
  late AppDatabase db;
  late ChapterDao dao;

  setUp(() async {
    db = createTestDb();
    await _seedBookAndVolume(db);
    dao = ChapterDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ChapterDao', () {
    test('insert and get chapters by volume', () async {
      await dao.insertChapter(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: const Value(_volumeId),
        title: const Value('第一章'),
        content: const Value(''),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final chapters = await dao.getChaptersByVolume(_volumeId);
      expect(chapters.length, 1);
      expect(chapters.first.title, '第一章');
    });

    test('get chapters ordered by sortOrder', () async {
      await dao.insertChapter(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: const Value(_volumeId),
        title: const Value('Ch2'),
        content: const Value(''),
        sortOrder: const Value(2),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      await dao.insertChapter(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: const Value(_volumeId),
        title: const Value('Ch1'),
        content: const Value(''),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final chapters = await dao.getChaptersByVolume(_volumeId);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Ch1');
      expect(chapters[1].title, 'Ch2');
    });

    test('get chapter by id', () async {
      final id = generateId();
      await dao.insertChapter(ChaptersCompanion(
        id: Value(id),
        volumeId: const Value(_volumeId),
        title: const Value('Found'),
        content: const Value('text'),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final chapter = await dao.getChapterById(id);
      expect(chapter, isNotNull);
      expect(chapter!.content, 'text');

      final notFound = await dao.getChapterById('nonexistent');
      expect(notFound, isNull);
    });

    test('update chapter content', () async {
      final id = generateId();
      await dao.insertChapter(ChaptersCompanion(
        id: Value(id),
        volumeId: const Value(_volumeId),
        title: const Value('Ch'),
        content: const Value('old content'),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.updateChapterContent(id, 'updated content');
      final chapter = await dao.getChapterById(id);
      expect(chapter!.content, 'updated content');
      expect(chapter.wordCount, 'updated content'.length);
    });

    test('update chapter title', () async {
      final id = generateId();
      await dao.insertChapter(ChaptersCompanion(
        id: Value(id),
        volumeId: const Value(_volumeId),
        title: const Value('Old Title'),
        content: const Value(''),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.updateChapterTitle(id, 'New Title');
      final chapter = await dao.getChapterById(id);
      expect(chapter!.title, 'New Title');
    });

    test('delete chapter', () async {
      final id = generateId();
      await dao.insertChapter(ChaptersCompanion(
        id: Value(id),
        volumeId: const Value(_volumeId),
        title: const Value('To Delete'),
        content: const Value(''),
        sortOrder: const Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.deleteChapter(id);
      final chapters = await dao.getChaptersByVolume(_volumeId);
      expect(chapters, isEmpty);
    });
  });
}
