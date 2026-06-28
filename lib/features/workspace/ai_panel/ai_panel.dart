import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/models/ai_model_config.dart';
import '../../../core/ai/prompts/prompts.dart';
import '../../../core/database/providers.dart';
import '../../book_analysis/book_analysis_screen.dart';
import '../../character/character_list_screen.dart';
import '../../settings/settings_screen.dart';
import '../models/selection_state.dart';

/// AI 辅助面板 - 右侧栏对话界面
class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key});

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    setState(() { _messages.add(_ChatMessage(role: 'user', content: text)); _isLoading = true; });
    _inputController.clear();
    _scrollToBottom();
    try {
      final config = await ref.read(aiConfigProvider.future);
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        setState(() { _messages.add(const _ChatMessage(role: 'assistant', content: '⚠️ 请先在 设置 → AI 模型配置 中填写 API Key')); _isLoading = false; });
        return;
      }
      final client = AiClient();
      final response = await client.chat(
        provider: config.provider, apiKey: config.apiKey!,
        messages: [
          const AiMessage(role: 'system', content: AiPrompts.systemWriter),
          ..._messages.where((m) => m.role != 'system').map((m) => AiMessage(role: m.role, content: m.content)),
        ],
      );
      setState(() { _messages.add(_ChatMessage(role: 'assistant', content: response.content)); _isLoading = false; });
      _scrollToBottom();
    } catch (e) {
      setState(() { _messages.add(_ChatMessage(role: 'assistant', content: '❌ 请求失败: $e')); _isLoading = false; });
    }
  }

  Future<void> _quickAction(String action) async {
    // 导航类操作：不用 await，直接用 ref.read（同步访问）
    if (action == 'analyzeBook') {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAnalysisScreen()));
      return;
    }
    if (action == 'manageCharacters') {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterListScreen()));
      return;
    }

    // 需要章节上下文的操作
    String chapterContext = '';
    try {
      final chapterId = ref.read(selectedChapterProvider);
      if (chapterId != null) {
        final chapterDao = ref.read(chapterDaoProvider);
        final chapter = await chapterDao.getChapterById(chapterId);
        if (chapter != null && mounted) {
          chapterContext = chapter.content.substring(0, chapter.content.length > 500 ? 500 : chapter.content.length);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    switch (action) {
      case 'outline':
        _inputController.text = '请帮我为以下故事生成详细章节大纲（10-20章）：\n\n故事核心：\n';
        break;
      case 'expand':
        _inputController.text = '请根据以下细纲扩写成一篇完整的网文章节：\n\n细纲：\n';
        break;
      case 'naming':
        await _sendMessage('请为网文生成一些角色名（主角、配角、反派各5个）：\n风格：古风玄幻');
        return;
      case 'writerBlock':
        _inputController.text = chapterContext.isNotEmpty
            ? '我卡文了。当前章节最近内容：\n$chapterContext\n\n请给我3-5个后续发展方向建议。'
            : '我卡文了，需要一些剧情发展建议。\n\n请给一些通用的网文剧情推进思路。';
        break;
    }
  }

  void _insertToEditor(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已复制到剪贴板，Ctrl+V 粘贴到编辑器'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          _buildQuickActions(theme),
          const Divider(height: 1),
          Expanded(child: _buildMessageList(theme)),
          const Divider(height: 1),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('AI 助手', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 18),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          tooltip: 'AI 设置', constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(Icons.delete_sweep_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => setState(() => _messages.clear()),
          tooltip: '清空对话', constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero,
        ),
      ]),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          ActionChip(avatar: const Icon(Icons.account_tree_outlined, size: 14), label: const Text('大纲梳理', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('outline')),
          ActionChip(avatar: const Icon(Icons.auto_stories_outlined, size: 14), label: const Text('细纲扩写', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('expand')),
          ActionChip(avatar: const Icon(Icons.abc_outlined, size: 14), label: const Text('起名', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('naming')),
          ActionChip(avatar: const Icon(Icons.lightbulb_outline, size: 14), label: const Text('卡文助手', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('writerBlock')),
          const SizedBox(width: 6),
          ActionChip(avatar: const Icon(Icons.auto_stories, size: 14), label: const Text('拆书', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('analyzeBook')),
          ActionChip(avatar: const Icon(Icons.people_outline, size: 14), label: const Text('人物', style: TextStyle(fontSize: 12)), onPressed: () => _quickAction('manageCharacters')),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    if (_messages.isEmpty && !_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
          const SizedBox(height: 8),
          Text('向 AI 助手提问', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('或使用上方快捷功能', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120))),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.primaryContainer, child: Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.onPrimaryContainer)),
                    const SizedBox(width: 8),
                  ],
                  if (isUser) const Spacer(),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8).copyWith(
                          bottomRight: isUser ? Radius.zero : null, bottomLeft: !isUser ? Radius.zero : null,
                        ),
                      ),
                      child: Text(msg.content, style: TextStyle(fontSize: 13, color: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface)),
                    ),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 8),
                    CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.secondaryContainer, child: Icon(Icons.person, size: 12, color: theme.colorScheme.onSecondaryContainer)),
                  ],
                  if (!isUser) const Spacer(),
                ],
              ),
              // AI 消息底部操作按钮
              if (!isUser) Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_copy, size: 14),
                      onPressed: () => _insertToEditor(msg.content),
                      tooltip: '复制到剪贴板',
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            maxLines: 3, minLines: 1,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: '输入问题...', isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (v) => _sendMessage(v),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _isLoading ? null : () => _sendMessage(_inputController.text),
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          tooltip: '发送',
        ),
      ]),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  const _ChatMessage({required this.role, required this.content});
}
