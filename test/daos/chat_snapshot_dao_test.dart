import 'package:flutter_test/flutter_test.dart';

import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/ai_chat_dao.dart';
import 'package:writer_assistant/core/database/daos/snapshot_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('AiChatDao', () {
    test('replaceAll persists then reloads in order', () async {
      final dao = AiChatDao(db);
      await dao.replaceAll(const [
        ChatMessage(role: 'user', content: '你好'),
        ChatMessage(role: 'assistant', content: '嗨'),
      ]);

      final messages = await dao.getAllMessages();
      expect(messages.length, 2);
      expect(messages[0].role, 'user');
      expect(messages[0].content, '你好');
      expect(messages[1].role, 'assistant');
    });

    test('clear removes everything', () async {
      final dao = AiChatDao(db);
      await dao.replaceAll(const [ChatMessage(role: 'user', content: 'x')]);
      await dao.clear();

      expect(await dao.getAllMessages(), isEmpty);
    });
  });

  group('SnapshotDao', () {
    test('createSnapshot and getSnapshots newest first', () async {
      final dao = SnapshotDao(db);
      final chapterId = generateId();
      await dao.createSnapshot(chapterId, 'v1-title', 'v1-content');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.createSnapshot(chapterId, 'v2-title', 'v2-content');

      final snapshots = await dao.getSnapshots(chapterId);
      expect(snapshots.length, 2);
      expect(snapshots.first.title, 'v2-title');
      expect(snapshots.last.title, 'v1-title');
    });

    test('deleteSnapshotsByChapter only removes the chapter', () async {
      final dao = SnapshotDao(db);
      final ch1 = generateId();
      final ch2 = generateId();
      await dao.createSnapshot(ch1, 'a', 'aaa');
      await dao.createSnapshot(ch2, 'b', 'bbb');

      await dao.deleteSnapshotsByChapter(ch1);
      expect(await dao.getSnapshots(ch1), isEmpty);
      expect(await dao.getSnapshots(ch2), hasLength(1));
    });
  });
}