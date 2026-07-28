import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前选中的章节 ID
final selectedChapterProvider = StateProvider<String?>((ref) => null);

/// 当前选中的书籍 ID
final selectedBookProvider = StateProvider<String?>((ref) => null);

/// 触发目录树刷新
final treeRefreshProvider = StateProvider<int>((ref) => 0);

/// 写作状态（字数、速度）
class WritingState {
  final int wordCount;
  final int writingSpeed;
  final String sessionDuration;

  const WritingState({
    this.wordCount = 0,
    this.writingSpeed = 0,
    this.sessionDuration = '',
  });
}

final writingStateProvider = StateProvider<WritingState>((ref) => const WritingState());

/// 强制保存信号（触发即时保存，绕过防抖）
final forceSaveProvider = StateProvider<int>((ref) => 0);

/// 新建章节信号
final newChapterRequestProvider = StateProvider<int>((ref) => 0);

/// 新建书籍信号
final newBookRequestProvider = StateProvider<int>((ref) => 0);

/// AI 上下文选中的章节 ID 集合
final selectedContextChaptersProvider = StateProvider<Set<String>>((ref) => {});

/// AI 上下文配置
class AiContextConfig {
  final int maxChapters;
  final int maxChars;

  const AiContextConfig({
    this.maxChapters = 10,
    this.maxChars = 20000,
  });
}

final aiContextConfigProvider = StateProvider<AiContextConfig>((ref) => const AiContextConfig());

/// AI 对话消息（持久化，跨面板生命周期）
class AiChatMessage {
  final String role;
  final String content;
  const AiChatMessage({required this.role, required this.content});
}

final aiChatMessagesProvider = StateProvider<List<AiChatMessage>>((ref) => []);

