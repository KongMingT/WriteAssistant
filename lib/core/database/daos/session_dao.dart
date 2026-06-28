import 'package:drift/drift.dart';

import '../database.dart';

class SessionDao extends DatabaseAccessor<AppDatabase> {
  SessionDao(super.db);

  /// 获取某本书的所有写作记录
  Future<List<WritingSession>> getSessionsByBook(String bookId) async {
    return (select(db.writingSessions)
          ..where((s) => s.bookId.equals(bookId))
          ..orderBy([(s) => OrderingTerm(expression: s.startTime)]))
        .get();
  }

  /// 开始一次写作记录
  Future<void> startSession(WritingSessionsCompanion session) async {
    await into(db.writingSessions).insert(session);
  }

  /// 结束写作记录
  Future<void> endSession(String id, int wordCount) async {
    await (update(db.writingSessions)..where((s) => s.id.equals(id))).write(
      WritingSessionsCompanion(
        endTime: Value(DateTime.now()),
        wordCount: Value(wordCount),
      ),
    );
  }
}
