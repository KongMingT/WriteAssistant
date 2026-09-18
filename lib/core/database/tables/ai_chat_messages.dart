import 'package:drift/drift.dart';

/// AI 对话消息（跨面板持久化，重启不丢失）
class AiChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}