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
        volumeId: Value(_volumeId),
        title: Value('第一章'),
        content: Value(''),
        sortOrder: Value(1),
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
        volumeId: Value(_volumeId),
        title: Value('Ch2'),
        content: Value(''),
        sortOrder: Value(2),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      await dao.insertChapter(ChaptersCompanion(
        id: Value(generateId()),
        volumeId: Value(_volumeId),
        title: Value('Ch1'),
        content: Value(''),
        sortOrder: Value(1),
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
        volumeId: Value(_volumeId),
        title: Value('Found'),
        content: Value('text'),
        sortOrder: Value(1),
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
        volumeId: Value(_volumeId),
        title: Value('Ch'),
        content: Value('old content'),
        sortOrder: Value(1),
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
        volumeId: Value(_volumeId),
        title: Value('Old Title'),
        content: Value(''),
        sortOrder: Value(1),
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
        volumeId: Value(_volumeId),
        title: Value('To Delete'),
        content: Value(''),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.deleteChapter(id);
      final chapters = await dao.getChaptersByVolume(_volumeId);
      expect(chapters, isEmpty);
    });
  });
}
