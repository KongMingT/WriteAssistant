import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/volume_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'volume-test-book';

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
  late VolumeDao dao;

  setUp(() async {
    db = createTestDb();
    await _seedBook(db);
    dao = VolumeDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('VolumeDao', () {
    test('insert and get volumes by book', () async {
      await dao.insertVolume(VolumesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        title: Value('第一卷'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      final volumes = await dao.getVolumesByBook(_bookId);
      expect(volumes.length, 1);
      expect(volumes.first.title, '第一卷');
    });

    test('get volumes ordered by sortOrder', () async {
      await dao.insertVolume(VolumesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        title: Value('V2'),
        sortOrder: Value(2),
        createdAt: Value(DateTime.now()),
      ));
      await dao.insertVolume(VolumesCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        title: Value('V1'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      final volumes = await dao.getVolumesByBook(_bookId);
      expect(volumes.length, 2);
      expect(volumes[0].title, 'V1');
      expect(volumes[1].title, 'V2');
    });

    test('get volume by id', () async {
      final id = generateId();
      await dao.insertVolume(VolumesCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        title: Value('Found'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      final volume = await dao.getVolumeById(id);
      expect(volume, isNotNull);
      expect(volume!.title, 'Found');

      final notFound = await dao.getVolumeById('nonexistent');
      expect(notFound, isNull);
    });

    test('update volume', () async {
      final id = generateId();
      await dao.insertVolume(VolumesCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        title: Value('Original'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      final volume = await dao.getVolumeById(id);
      await dao.updateVolume(volume!.copyWith(title: 'Updated'));

      final updated = await dao.getVolumeById(id);
      expect(updated!.title, 'Updated');
    });

    test('delete volume', () async {
      final id = generateId();
      await dao.insertVolume(VolumesCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        title: Value('To Delete'),
        sortOrder: Value(1),
        createdAt: Value(DateTime.now()),
      ));

      await dao.deleteVolume(id);
      final volumes = await dao.getVolumesByBook(_bookId);
      expect(volumes, isEmpty);
    });
  });
}
