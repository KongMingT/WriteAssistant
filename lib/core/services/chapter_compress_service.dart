import 'package:drift/drift.dart';

import '../ai/ai_client.dart';
import '../ai/models/ai_model_config.dart';
import '../ai/prompts/prompts.dart';
import '../database/daos/outline_dao.dart';
import '../database/database.dart';
import '../utils/id_generator.dart';

class ChapterSummary {
  final String chapterId;
  final String title;
  final String summary;

  ChapterSummary({
    required this.chapterId,
    required this.title,
    required this.summary,
  });
}

class ChapterCompressService {
  final AiClient _client;
  final OutlineDao _outlineDao;

  ChapterCompressService(this._client, this._outlineDao);

  static const _maxBatchChars = 15000;

  Future<List<ChapterSummary>> compress({
    required List<Chapter> chapters,
    required AiProvider provider,
    required String apiKey,
    required String bookId,
  }) async {
    if (chapters.isEmpty) return [];

    final sorted = [...chapters]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final allSummaries = <ChapterSummary>[];
    int batchStart = 0;
    while (batchStart < sorted.length) {
      final batch = <Chapter>[];
      int charCount = 0;
      for (int i = batchStart; i < sorted.length; i++) {
        final ch = sorted[i];
        final chLen = ch.title.length + ch.content.length + 50;
        if (charCount + chLen > _maxBatchChars && batch.isNotEmpty) break;
        batch.add(ch);
        charCount += chLen;
      }
      if (batch.isEmpty) break;
      batchStart += batch.length;

      final prompt = AiPrompts.compressChapters(_buildBatchText(batch));
      final response = await _client.chat(
        provider: provider,
        apiKey: apiKey,
        messages: [
          const AiMessage(role: 'system', content: '你是一个专业的网文章节摘要工具。只输出要求的格式，不要多余说明。'),
          AiMessage(role: 'user', content: prompt),
        ],
      );

      final summaries = _parseResponse(response.content, batch);
      allSummaries.addAll(summaries);
    }

    if (allSummaries.isNotEmpty) {
      await _writeSummaries(allSummaries, bookId);
    }

    return allSummaries;
  }

  String _buildBatchText(List<Chapter> batch) {
    final buf = StringBuffer();
    for (int i = 0; i < batch.length; i++) {
      final ch = batch[i];
      buf.writeln('## 章节 #${i + 1}');
      buf.writeln('标题：${ch.title}');
      buf.writeln('内容：');
      buf.writeln(ch.content);
      buf.writeln();
    }
    return buf.toString();
  }

  List<ChapterSummary> _parseResponse(String response, List<Chapter> batch) {
    final results = <ChapterSummary>[];
    final sections = response.split(RegExp(r'\n(?=##\s*章节\s+#\d+)'));
    final linePattern = RegExp(r'##\s*章节\s+#(\d+)\s*\n标题：(.+)\n摘要：(.+)');

    for (final section in sections) {
      final match = linePattern.firstMatch(section.trim());
      if (match == null) continue;
      final index = int.tryParse(match.group(1) ?? '') ?? 0;
      if (index < 1 || index > batch.length) continue;
      final ch = batch[index - 1];
      results.add(ChapterSummary(
        chapterId: ch.id,
        title: match.group(2)?.trim() ?? ch.title,
        summary: match.group(3)?.trim() ?? '',
      ));
    }

    return results;
  }

  Future<void> _writeSummaries(List<ChapterSummary> summaries, String bookId) async {
    for (final s in summaries) {
      if (s.summary.isEmpty) continue;

      final existing = await _outlineDao.getOutlineNodesByChapter(s.chapterId);
      for (final node in existing) {
        await _outlineDao.deleteOutlineNode(node.id);
      }

      await _outlineDao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        chapterId: Value(s.chapterId),
        parentId: const Value(null),
        title: Value(s.title),
        content: Value(s.summary),
        sortOrder: const Value(0),
        type: const Value('chapter_summary'),
        status: const Value('final'),
      ));
    }
  }
}
