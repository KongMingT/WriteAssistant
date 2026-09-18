import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/ai_chat_dao.dart'
    show AiChatDao, ChatMessage;
import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';

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

/// 写作统计数据刷新信号（结束写作会话后触发，用于刷新趋势）
final writingStatsRefreshProvider = StateProvider<int>((ref) => 0);

/// 强制保存信号（触发即时保存，绕过防抖）
final forceSaveProvider = StateProvider<int>((ref) => 0);

/// 新建章节信号
final newChapterRequestProvider = StateProvider<int>((ref) => 0);

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

/// AI 对话控制器：启动时从数据库加载，增删后自动落库
class AiChatController extends StateNotifier<List<ChatMessage>> {
  AiChatController(this._dao) : super(const []) {
    _load();
  }

  final AiChatDao _dao;
  bool _loaded = false;

  Future<void> _load() async {
    final messages = await _dao.getAllMessages();
    if (!mounted) return;
    _loaded = true;
    state = messages;
  }

  void _persist() {
    if (!_loaded) return;
    _dao.replaceAll(state);
  }

  /// 追加消息并持久化
  void add(ChatMessage message) {
    state = [...state, message];
    _persist();
  }

  /// 追加或替换最后一条 assistant 消息（流式输出中不持久化）
  void upsertAssistant(String content) {
    final msg = ChatMessage(role: 'assistant', content: content);
    if (state.isNotEmpty && state.last.role == 'assistant') {
      state = [...state.sublist(0, state.length - 1), msg];
    } else {
      state = [...state, msg];
    }
  }

  /// 强制落库当前对话（流式结束后调用）
  void persistNow() => _persist();

  /// 清空对话并删除数据库记录
  void clearAll() {
    state = const [];
    _dao.clear();
  }
}

final aiChatMessagesProvider =
    StateNotifierProvider<AiChatController, List<ChatMessage>>(
  (ref) => AiChatController(ref.read(aiChatDaoProvider)),
);

/// 大纲编辑器中当前选中的节点
final selectedOutlineNodeProvider = StateProvider<OutlineNode?>((ref) => null);

/// 大纲树刷新信号
final outlineTreeRefreshProvider = StateProvider<int>((ref) => 0);

