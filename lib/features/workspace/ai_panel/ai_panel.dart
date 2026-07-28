import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/models/ai_model_config.dart';
import '../../../core/ai/prompts/prompts.dart';
import '../../../core/database/database.dart';
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
  bool _showChapterSelector = false;
  List<Volume> _volumes = [];
  List<Chapter> _allChapters = [];
  bool _selectorLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterSelector() async {
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null) return;
    setState(() => _selectorLoading = true);
    try {
      final volumeDao = ref.read(volumeDaoProvider);
      final chapterDao = ref.read(chapterDaoProvider);
      final volumes = await volumeDao.getVolumesByBook(bookId);
      final allChapters = <Chapter>[];
      for (final vol in volumes) {
        allChapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
      }
      if (mounted) {
        setState(() {
          _volumes = volumes;
          _allChapters = allChapters;
          _selectorLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _selectorLoading = false);
    }
  }

  Future<String> _buildContext() async {
    final config = ref.read(aiContextConfigProvider);
    final maxChars = config.maxChars;
    final buffer = StringBuffer();
    int totalChars = 0;

    // 1. Selected chapters
    final selectedIds = ref.read(selectedContextChaptersProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final selectedChapters = <Chapter>[];
    for (final id in selectedIds) {
      final ch = await chapterDao.getChapterById(id);
      if (ch != null) selectedChapters.add(ch);
    }
    selectedChapters.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

    if (selectedChapters.isNotEmpty) {
      buffer.writeln('【上下文章节】');
      for (final ch in selectedChapters) {
        final remaining = maxChars - totalChars;
        if (remaining <= 0) break;
        final content = ch.content.length > remaining
            ? ch.content.substring(0, remaining)
            : ch.content;
        totalChars += content.length;
        buffer.writeln('--- ${ch.title} ---');
        buffer.writeln(content);
        buffer.writeln();
      }
    }

    // 2. Current chapter (first 2000 chars)
    final chapterId = ref.read(selectedChapterProvider);
    if (chapterId != null && !selectedIds.contains(chapterId)) {
      final ch = await chapterDao.getChapterById(chapterId);
      if (ch != null) {
        final remaining = maxChars - totalChars;
        if (remaining > 0 && ch.content.isNotEmpty) {
          buffer.writeln('【当前章节】');
          final content = ch.content.length > 2000
              ? ch.content.substring(0, 2000)
              : ch.content.length > remaining
                  ? ch.content.substring(0, remaining)
                  : ch.content;
          final actualLen = content.length > 2000 ? 2000 : content.length;
          final truncated = content.substring(0, actualLen > remaining ? remaining : actualLen);
          totalChars += truncated.length;
          buffer.writeln('--- ${ch.title}（前${truncated.length}字）---');
          buffer.writeln(truncated);
          buffer.writeln();
        }
      }
    }

    // 3. Character list (first 500 chars)
    final bookId = ref.read(selectedBookProvider);
    if (bookId != null) {
      final characterDao = ref.read(characterDaoProvider);
      final characters = await characterDao.getCharactersByBook(bookId);
      if (characters.isNotEmpty) {
        final remaining = maxChars - totalChars;
        if (remaining > 0) {
          buffer.writeln('【角色设定】');
          final charText = characters
              .map((c) => '- ${c.name}（${c.roleType}）${c.personality != null && c.personality!.isNotEmpty ? "性格：${c.personality}" : ""}')
              .join('\n');
          final truncated = charText.length > remaining
              ? charText.substring(0, remaining)
              : charText;
          buffer.writeln(truncated);
        }
      }
    }

    final result = buffer.toString().trim();
    return result.isNotEmpty ? '\n\n---\n$result' : '';
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

      String userText = text;
      try {
        final context = await _buildContext();
        if (context.isNotEmpty) {
          userText = '$text$context';
        }
      } catch (_) {}

      final client = AiClient();
      final apiMessages = [
        const AiMessage(role: 'system', content: AiPrompts.systemWriter),
        ..._messages.where((m) => m.role != 'system').map((m) => AiMessage(role: m.role, content: m.content)),
      ];
      if (apiMessages.isNotEmpty && apiMessages.last.role == 'user') {
        apiMessages.last = AiMessage(role: 'user', content: userText);
      }

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

    if (!mounted) return;

    switch (action) {
      case 'outline':
        await _sendMessage([
          '请为我生成一份详细的章节大纲（10-20章）：',
          '',
          '要求：每章给出标题、核心内容、爽点/钩子，前后连贯。',
        ].join('\n\n'));
        break;
      case 'expand':
        await _sendMessage([
          '请根据以下细纲扩写成一篇完整的网文章节（约3000-4000字）。',
          '直接输出正文，不要加额外说明。',
          '',
          '细纲（请在下面填写你的细纲内容）：',
        ].join('\n\n'));
        break;
      case 'naming':
        await _sendMessage(AiPrompts.naming('小说角色', style: '古风玄幻', count: 15));
        break;
      case 'writerBlock':
        await _sendMessage([
          '作者在写小说时卡住了，需要你的帮助。',
          '',
          '请给出 3-5 个不同的发展方向建议，每个建议包括：',
          '1. 发展方向简述',
          '2. 具体的剧情走向',
          '3. 这个方向能带来的爽点/看点',
          '',
          '要求：不要太过跳脱，要符合当前故事逻辑。',
        ].join('\n'));
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
          _buildQuickActions(theme, fontFamily),
          if (_showChapterSelector) ...[
            const Divider(height: 1),
            _buildChapterSelector(theme, fontFamily),
          ],
          const Divider(height: 1),
          Expanded(child: _buildMessageList(theme, fontFamily)),
          const Divider(height: 1),
          _buildInputArea(theme, fontFamily),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final selectedCount = ref.watch(selectedContextChaptersProvider).length;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('AI 助手', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        if (selectedCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('已选$selectedCount章', style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
        IconButton(
          icon: Icon(
            _showChapterSelector ? Icons.checklist : Icons.checklist_outlined,
            size: 18,
            color: _showChapterSelector ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            setState(() => _showChapterSelector = !_showChapterSelector);
            if (_showChapterSelector && _volumes.isEmpty) {
              _loadChapterSelector();
            }
          },
          tooltip: '选择上下文章节',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
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

  Widget _buildQuickActions(ThemeData theme, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          ActionChip(avatar: const Icon(Icons.account_tree_outlined, size: 14), label: Text('大纲梳理', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('outline')),
          ActionChip(avatar: const Icon(Icons.auto_stories_outlined, size: 14), label: Text('细纲扩写', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('expand')),
          ActionChip(avatar: const Icon(Icons.abc_outlined, size: 14), label: Text('起名', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('naming')),
          ActionChip(avatar: const Icon(Icons.lightbulb_outline, size: 14), label: Text('卡文助手', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('writerBlock')),
          const SizedBox(width: 6),
          ActionChip(avatar: const Icon(Icons.auto_stories, size: 14), label: Text('拆书', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('analyzeBook')),
          ActionChip(avatar: const Icon(Icons.people_outline, size: 14), label: Text('人物', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('manageCharacters')),
        ],
      ),
    );
  }

  Widget _buildChapterSelector(ThemeData theme, String fontFamily) {
    final selectedIds = ref.watch(selectedContextChaptersProvider);
    final config = ref.read(aiContextConfigProvider);
    int totalChars = 0;
    for (final id in selectedIds) {
      final ch = _allChapters.where((c) => c.id == id).firstOrNull;
      if (ch != null) totalChars += ch.content.length;
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('选择上下文章节', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text(
                  '已选 ${selectedIds.length}/${config.maxChapters} 章，${totalChars > 1000 ? "${(totalChars / 1000).toStringAsFixed(1)}k" : "$totalChars"} 字',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                if (selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(selectedContextChaptersProvider.notifier).state = {},
                    child: Text('清除', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectorLoading
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : _volumes.isEmpty
                    ? Center(child: Text('暂无章节', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)))
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        children: _volumes.map((vol) => _buildVolumeCheckboxes(vol, selectedIds, theme, fontFamily)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeCheckboxes(Volume vol, Set<String> selectedIds, ThemeData theme, String fontFamily) {
    final volChapters = _allChapters.where((c) => c.volumeId == vol.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2, right: 8),
          child: Row(children: [
            Icon(Icons.folder_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(child: Text(vol.title, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant))),
            Text('${volChapters.length}章', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withAlpha(120))),
          ]),
        ),
        ...volChapters.map((ch) => _buildChapterCheckbox(ch, selectedIds, theme, fontFamily)),
      ],
    );
  }

  Widget _buildChapterCheckbox(Chapter chapter, Set<String> selectedIds, ThemeData theme, String fontFamily) {
    final isSelected = selectedIds.contains(chapter.id);
    return InkWell(
      onTap: () {
        final notifier = ref.read(selectedContextChaptersProvider.notifier);
        final config = ref.read(aiContextConfigProvider);
        final current = Set<String>.from(notifier.state);
        if (isSelected) {
          current.remove(chapter.id);
          notifier.state = current;
        } else {
          if (current.length >= config.maxChapters) return;
          current.add(chapter.id);
          notifier.state = current;
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 2),
        child: Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: Checkbox(
              value: isSelected,
              onChanged: (v) {
                final notifier = ref.read(selectedContextChaptersProvider.notifier);
                final config = ref.read(aiContextConfigProvider);
                final current = Set<String>.from(notifier.state);
                if (v == true) {
                  if (current.length >= config.maxChapters) return;
                  current.add(chapter.id);
                } else {
                  current.remove(chapter.id);
                }
                notifier.state = current;
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              chapter.title,
              style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chapter.wordCount > 0)
            Text('${chapter.wordCount}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
        ]),
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
