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

  /// 结束写作记录（可指定结束时间，缺省为当前时间）
  Future<void> endSession(String id, int wordCount, {DateTime? endTime}) async {
    await (update(db.writingSessions)..where((s) => s.id.equals(id))).write(
      WritingSessionsCompanion(
        endTime: Value(endTime ?? DateTime.now()),
        wordCount: Value(wordCount),
      ),
    );
  }

  /// 统计自某时间点起已结束写作的字数总和
  Future<int> getWordCountSince(DateTime since) async {
    final rows = await (select(db.writingSessions)
          ..where((s) => s.endTime.isNotNull() & s.endTime.isBiggerThanValue(since)))
        .get();
    return rows.fold<int>(0, (sum, s) => sum + s.wordCount);
  }

  /// 获取最近 N 天每日写作字数（含今天，从当天 0 点算起）
  Future<List<({DateTime day, int words})>> getDailyWordCounts(int days) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final since = today.subtract(Duration(days: days - 1));
    final rows = await (select(db.writingSessions)
          ..where((s) => s.endTime.isNotNull() & s.endTime.isBiggerOrEqualValue(since)))
        .get();
    final map = <DateTime, int>{};
    for (final s in rows) {
      final t = s.endTime!;
      final day = DateTime(t.year, t.month, t.day);
      map[day] = (map[day] ?? 0) + s.wordCount;
    }
    return List.generate(days, (i) {
      final day = since.add(Duration(days: i));
      return (day: day, words: map[day] ?? 0);
    });
  }

  /// 删除某本书的所有写作记录
  Future<void> deleteSessionsByBook(String bookId) async {
    await (delete(db.writingSessions)..where((s) => s.bookId.equals(bookId))).go();
  }
}
