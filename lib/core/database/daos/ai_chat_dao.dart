import 'package:drift/drift.dart';

import '../../utils/id_generator.dart';
import '../database.dart';

/// AI 对话消息（持久化的单条记录）
class ChatMessage {
  final String role;
  final String content;
  const ChatMessage({required this.role, required this.content});
}

/// AI 对话消息数据访问（持久化）
class AiChatDao extends DatabaseAccessor<AppDatabase> {
  AiChatDao(super.db);

  /// 读取全部消息（按时间正序）
  Future<List<ChatMessage>> getAllMessages() async {
    final rows = await (select(db.aiChatMessages)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map((r) => ChatMessage(role: r.role, content: r.content)).toList();
  }

  /// 覆盖保存整段对话（事务：清空后批量插入）
  Future<void> replaceAll(List<ChatMessage> messages) async {
    await db.transaction(() async {
      await delete(db.aiChatMessages).go();
      final now = DateTime.now();
      for (final m in messages) {
        await into(db.aiChatMessages).insert(AiChatMessagesCompanion.insert(
          id: generateId(),
          role: m.role,
          content: m.content,
          createdAt: now,
        ));
      }
    });
  }

  /// 清空对话
  Future<void> clear() async {
    await delete(db.aiChatMessages).go();
  }
}