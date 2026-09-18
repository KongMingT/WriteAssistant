import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/ai/ai_client.dart';
import 'package:writer_assistant/core/ai/models/ai_model_config.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/outline_dao.dart';
import 'package:writer_assistant/core/services/chapter_compress_service.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import '../daos/test_utils.dart';

class _FakeAiClient extends AiClient {
  final String _response;
  _FakeAiClient(this._response) : super();

  @override
  Future<AiResponse> chat({
    required AiProvider provider,
    required String apiKey,
    required List<AiMessage> messages,
    String model = '',
    bool stream = false,
  }) async {
    return AiResponse(content: _response);
  }
}

const _bookId = 'compress-test-book';
const _volumeId = 'compress-test-volume';

Future<void> _seed(AppDatabase db) async {
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
  for (int i = 1; i <= 3; i++) {
    final content = '这是第$i章的核心内容。' * 30;
    await db.into(db.chapters).insert(ChaptersCompanion(
          id: Value('ch$i'),
          volumeId: const Value(_volumeId),
          title: Value('第$i章'),
          content: Value(content),
          sortOrder: Value(i),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
  }
}

void main() {
  late AppDatabase db;
  late OutlineDao outlineDao;

  setUp(() async {
    db = createTestDb();
    await _seed(db);
    outlineDao = OutlineDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ChapterCompressService', () {
    test('compress parses AI response and writes back outline_nodes', () async {
      const fakeResponse = '''
## 章节 #1
标题：第1章
摘要：第一章的核心情节是主角登场，初步建立世界观。

## 章节 #2
标题：第2章
摘要：第二章的冲突升级，主角遇到第一个重要对手。

## 章节 #3
标题：第3章
摘要：第三章迎来小高潮，主角获得关键成长。
''';

      final fakeClient = _FakeAiClient(fakeResponse);
      final service = ChapterCompressService(fakeClient, outlineDao);

      final chapters = await db.select(db.chapters).get();
      final summaries = await service.compress(
        chapters: chapters,
        provider: AiProvider.deepseek,
        apiKey: 'fake-key',
        bookId: _bookId,
      );

      expect(summaries.length, 3);
      expect(summaries[0].chapterId, 'ch1');
      expect(summaries[0].summary.contains('主角登场'), true);
      expect(summaries[1].chapterId, 'ch2');
      expect(summaries[2].chapterId, 'ch3');

      final nodesCh1 = await outlineDao.getOutlineNodesByChapter('ch1');
      expect(nodesCh1.length, 1);
      expect(nodesCh1.first.content, contains('主角登场'));
      expect(nodesCh1.first.type, 'chapter_summary');
      expect(nodesCh1.first.status, 'final');
    });

    test('compress overwrites existing outline nodes for the same chapter', () async {
      await outlineDao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: const Value(_bookId),
        chapterId: const Value('ch1'),
        title: const Value('旧章纲'),
        content: const Value('旧内容'),
        sortOrder: const Value(0),
        type: const Value('section'),
      ));

      const fakeResponse = '''
## 章节 #1
标题：第1章
摘要：新压缩的内容。
''';

      final fakeClient = _FakeAiClient(fakeResponse);
      final service = ChapterCompressService(fakeClient, outlineDao);

      final chapters = await (db.select(db.chapters)..where((c) => c.id.equals('ch1'))).get();
      await service.compress(
        chapters: chapters,
        provider: AiProvider.deepseek,
        apiKey: 'fake-key',
        bookId: _bookId,
      );

      final nodes = await outlineDao.getOutlineNodesByChapter('ch1');
      expect(nodes.length, 1);
      expect(nodes.first.content, '新压缩的内容。');
      expect(nodes.first.type, 'chapter_summary');
    });

    test('compress with empty chapters returns empty list', () async {
      final fakeClient = _FakeAiClient('unused');
      final service = ChapterCompressService(fakeClient, outlineDao);

      final summaries = await service.compress(
        chapters: [],
        provider: AiProvider.deepseek,
        apiKey: 'fake-key',
        bookId: _bookId,
      );

      expect(summaries, isEmpty);
    });

    test('compress handles malformed AI response without crashing', () async {
      const fakeResponse = '这是一段完全无法解析的文本。';

      final fakeClient = _FakeAiClient(fakeResponse);
      final service = ChapterCompressService(fakeClient, outlineDao);

      final chapters = await db.select(db.chapters).get();
      final summaries = await service.compress(
        chapters: chapters,
        provider: AiProvider.deepseek,
        apiKey: 'fake-key',
        bookId: _bookId,
      );

      expect(summaries, isEmpty);
    });

    test('compress handles partial matches in AI response', () async {
      const fakeResponse = '''
## 章节 #1
标题：第1章
摘要：第一章摘要。

多余文本

## 章节 #3
标题：第3章
摘要：第三章摘要。
''';

      final fakeClient = _FakeAiClient(fakeResponse);
      final service = ChapterCompressService(fakeClient, outlineDao);

      final chapters = await db.select(db.chapters).get();
      final summaries = await service.compress(
        chapters: chapters,
        provider: AiProvider.deepseek,
        apiKey: 'fake-key',
        bookId: _bookId,
      );

      expect(summaries.length, 2);
      expect(summaries[0].chapterId, 'ch1');
      expect(summaries[1].chapterId, 'ch3');
    });
  });
}
