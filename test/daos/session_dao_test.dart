import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/session_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'session-test-book';

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
  late SessionDao dao;

  setUp(() async {
    db = createTestDb();
    await _seedBook(db);
    dao = SessionDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SessionDao', () {
    test('start and get sessions by book', () async {
      await dao.startSession(WritingSessionsCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        startTime: Value(DateTime.now()),
      ));

      final sessions = await dao.getSessionsByBook(_bookId);
      expect(sessions.length, 1);
    });

    test('get sessions ordered by startTime', () async {
      final now = DateTime.now();
      await dao.startSession(WritingSessionsCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        startTime: Value(now.subtract(const Duration(hours: 2))),
      ));
      await dao.startSession(WritingSessionsCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        startTime: Value(now),
      ));

      final sessions = await dao.getSessionsByBook(_bookId);
      expect(sessions.length, 2);
      expect(sessions[0].startTime.isBefore(sessions[1].startTime), isTrue);
    });

    test('end session updates endTime and wordCount', () async {
      final id = generateId();
      await dao.startSession(WritingSessionsCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        startTime: Value(DateTime.now()),
      ));

      await dao.endSession(id, 500);
      final sessions = await dao.getSessionsByBook(_bookId);

      expect(sessions.length, 1);
      expect(sessions.first.endTime, isNotNull);
      expect(sessions.first.wordCount, 500);
    });
  });
}
