import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/models/ai_model_config.dart';
import '../../../core/ai/prompts/prompts.dart';
import '../../../core/database/providers.dart';
import '../../../shared/themes/theme_provider.dart';
import '../../book_analysis/book_analysis_screen.dart';
import '../../character/character_list_screen.dart';
import '../../settings/settings_screen.dart';
import '../models/selection_state.dart';

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
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final config = await ref.read(aiConfigProvider.future);
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        setState(() {
          _messages.add(const _ChatMessage(role: 'assistant', content: '⚠️ 请先在 设置 → AI 模型配置 中填写 API Key'));
          _isLoading = false;
        });
        return;
      }

      final client = AiClient();
      final apiMessages = [
        const AiMessage(role: 'system', content: AiPrompts.systemWriter),
        ..._messages.where((m) => m.role != 'system').map((m) => AiMessage(role: m.role, content: m.content)),
      ];

      String accumulated = '';

      try {
        await for (final chunk in client.chatStream(
          provider: config.provider,
          apiKey: config.apiKey!,
          messages: apiMessages,
        )) {
          accumulated += chunk;
          if (mounted) {
            if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
              _messages.last = _ChatMessage(role: 'assistant', content: accumulated);
            } else {
              _messages.add(_ChatMessage(role: 'assistant', content: accumulated));
            }
            _scrollToBottom();
          }
        }
      } catch (_) {
        if (accumulated.isNotEmpty && mounted) {
          if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
            _messages.last = _ChatMessage(role: 'assistant', content: accumulated);
          }
        }
        rethrow;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isEmpty || _messages.last.role != 'assistant' || !_messages.last.content.startsWith('❌')) {
            _messages.add(_ChatMessage(role: 'assistant', content: '❌ 请求失败: $e'));
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _quickAction(String action) async {
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

    String chapterContext = '';
    String bookContext = '';
    try {
      final chapterId = ref.read(selectedChapterProvider);
      if (chapterId != null) {
        final chapterDao = ref.read(chapterDaoProvider);
        final chapter = await chapterDao.getChapterById(chapterId);
        if (chapter != null && mounted) {
          chapterContext = chapter.content.substring(0, chapter.content.length > 2000 ? 2000 : chapter.content.length);
        }
      }
      final bookId = ref.read(selectedBookProvider);
      if (bookId != null) {
        final characterDao = ref.read(characterDaoProvider);
        final characters = await characterDao.getCharactersByBook(bookId);
        if (characters.isNotEmpty) {
          bookContext = '当前书籍角色：\n${characters.map((c) => '- ${c.name}（${c.roleType}）${c.personality != null && c.personality!.isNotEmpty ? "性格：${c.personality}" : ""}').join('\n')}';
        }
      }
    } catch (_) {}

    if (!mounted) return;

    switch (action) {
      case 'outline':
        await _sendMessage([
          '请为我生成一份详细的章节大纲（10-20章）：',
          if (chapterContext.isNotEmpty) '现有章节内容参考（前2000字）：\n$chapterContext',
          if (bookContext.isNotEmpty) bookContext,
          '',
          '要求：每章给出标题、核心内容、爽点/钩子，前后连贯。',
        ].join('\n\n'));
        break;
      case 'expand':
        await _sendMessage([
          '请根据以下细纲扩写成一篇完整的网文章节（约3000-4000字）。',
          '直接输出正文，不要加额外说明。',
          if (bookContext.isNotEmpty) bookContext,
          if (chapterContext.isNotEmpty) '当前章节前文：\n$chapterContext',
          '',
          '细纲（请在下面填写你的细纲内容）：',
        ].join('\n\n'));
        break;
      case 'naming':
        await _sendMessage(AiPrompts.naming('小说角色', style: '古风玄幻', count: 15));
        break;
      case 'writerBlock':
        await _sendMessage(AiPrompts.writerBlock(
          chapterContext.isNotEmpty ? chapterContext : '(暂无近期内容)',
          bookContext.isNotEmpty ? bookContext : '(暂无书籍设定)',
        ));
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

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    const threshold = 50.0;
    return _scrollController.position.maxScrollExtent - _scrollController.position.pixels <= threshold;
  }

  void _scrollToBottom() {
    if (!_isNearBottom()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Widget> _buildMessageContent(String text, String fontFamily, bool isUser, ThemeData theme) {
    final baseColor = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final lines = text.split('\n');
    final List<Widget> widgets = [];
    bool prevWasBlank = true;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        prevWasBlank = true;
        continue;
      }

      if (prevWasBlank && widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
      }
      prevWasBlank = false;

      final isBold = trimmed.startsWith('**') && trimmed.endsWith('**') && trimmed.length > 4;
      final fontSize = isBold ? 14.0 : 13.0;

      widgets.add(
        SelectableText(
          isBold ? trimmed.substring(2, trimmed.length - 2) : trimmed,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: fontFamily,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: baseColor,
            height: 1.4,
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(SelectableText(text, style: TextStyle(fontSize: 13, fontFamily: fontFamily, color: baseColor)));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontFamily = ref.watch(editorFontFamilyProvider);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          _buildQuickActions(theme),
          const Divider(height: 1),
          Expanded(child: _buildMessageList(theme, fontFamily)),
          const Divider(height: 1),
          _buildInputArea(theme, fontFamily),
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

  Widget _buildMessageList(ThemeData theme, String fontFamily) {
    if (_messages.isEmpty && !_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
          const SizedBox(height: 8),
          Text('向 AI 助手提问', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontFamily: fontFamily)),
          const SizedBox(height: 4),
          Text('或使用上方快捷功能', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120), fontFamily: fontFamily)),
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
                          bottomRight: isUser ? Radius.zero : null,
                          bottomLeft: !isUser ? Radius.zero : null,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildMessageContent(msg.content, fontFamily, isUser, theme),
                      ),
                    ),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 8),
                    CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.secondaryContainer, child: Icon(Icons.person, size: 12, color: theme.colorScheme.onSecondaryContainer)),
                  ],
                  if (!isUser) const Spacer(),
                ],
              ),
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

  Widget _buildInputArea(ThemeData theme, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            maxLines: 3, minLines: 1,
            style: TextStyle(fontSize: 13, fontFamily: fontFamily),
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
