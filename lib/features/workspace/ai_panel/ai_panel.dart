import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/models/ai_model_config.dart';
import '../../../core/ai/prompts/prompts.dart';
import '../../../core/database/daos/ai_chat_dao.dart' show ChatMessage;
import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';
import '../../../core/services/chapter_compress_service.dart';
import '../../../core/utils/id_generator.dart';
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

// ===== Top-level Helper Classes =====

class _ChapterWithOutline {
  final Chapter chapter;
  final String volumeTitle;
  final String outlineText;

  _ChapterWithOutline({
    required this.chapter,
    required this.volumeTitle,
    required this.outlineText,
  });
}

class _ExpandOutlineData {
  final Chapter chapter;
  final String outlineText;

  _ExpandOutlineData({
    required this.chapter,
    required this.outlineText,
  });
}

class _NamingParams {
  final String surname;
  final bool isDoubleSurname;
  final String gender;
  final String style;
  final int count;

  _NamingParams({
    required this.surname,
    required this.isDoubleSurname,
    required this.gender,
    required this.style,
    required this.count,
  });
}

class _AiPanelState extends ConsumerState<AiPanel> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showChapterSelector = false;
  List<Volume> _volumes = [];
  List<Chapter> _allChapters = [];
  bool _selectorLoading = false;

  // Naming preferences (persisted)
  String _namingSurname = '';
  bool _namingIsDoubleSurname = false;
  String _namingGender = 'male';
  String _namingStyle = 'xuanhuan';
  int _namingCount = 15;
  List<String> _namingResults = [];

  // U1: Tabbed panel architecture
  late TabController _tabController;
  static const _tabLabels = ['细纲扩写', '起名工具', '卡文助手', 'AI对话'];
  double _aiPanelWidth = 360;
  bool _aiPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadNamingPrefs();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNamingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _namingSurname = prefs.getString('naming_surname') ?? '';
      _namingIsDoubleSurname = prefs.getBool('naming_double_surname') ?? false;
      _namingGender = prefs.getString('naming_gender') ?? 'male';
      _namingStyle = prefs.getString('naming_style') ?? 'xuanhuan';
      _namingCount = prefs.getInt('naming_count') ?? 15;
    });
  }

  Future<void> _saveNamingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('naming_surname', _namingSurname);
    await prefs.setBool('naming_double_surname', _namingIsDoubleSurname);
    await prefs.setString('naming_gender', _namingGender);
    await prefs.setString('naming_style', _namingStyle);
    await prefs.setInt('naming_count', _namingCount);
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
    ref.read(aiChatMessagesProvider.notifier).add(ChatMessage(role: 'user', content: text));
    setState(() => _isLoading = true);
    _inputController.clear();
    _scrollToBottom();

    try {
      final config = await ref.read(aiConfigProvider.future);
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        setState(() {
          ref.read(aiChatMessagesProvider.notifier)
              .add(const ChatMessage(role: 'assistant', content: '⚠️ 请先在 设置 → AI 模型配置 中填写 API Key'));
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
      final messages = ref.read(aiChatMessagesProvider);
      final apiMessages = [
        const AiMessage(role: 'system', content: AiPrompts.systemWriter),
        ...messages.where((m) => m.role != 'system').map((m) => AiMessage(role: m.role, content: m.content)),
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
            ref.read(aiChatMessagesProvider.notifier).upsertAssistant(accumulated);
            _scrollToBottom();
          }
        }
      } catch (_) {
        if (accumulated.isNotEmpty && mounted) {
          ref.read(aiChatMessagesProvider.notifier).upsertAssistant(accumulated);
        }
        rethrow;
      }

      ref.read(aiChatMessagesProvider.notifier).persistNow();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        final current = ref.read(aiChatMessagesProvider);
        final lastMsg = current.isNotEmpty ? current.last : null;
        if (lastMsg == null || lastMsg.role != 'assistant' || !lastMsg.content.startsWith('❌')) {
          ref.read(aiChatMessagesProvider.notifier)
              .add(ChatMessage(role: 'assistant', content: '❌ 请求失败: $e'));
        }
        ref.read(aiChatMessagesProvider.notifier).persistNow();
        setState(() => _isLoading = false);
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
      case 'bookPlanning':
        await _handleBookPlanning();
        break;
      case 'expand':
        await _showExpandOutlineDialog();
        break;
      case 'naming':
        await _showNamingPanel();
        break;
      case 'writerBlock':
        await _handleWriterBlock();
        break;
      // ===== 大纲系统快捷操作 =====
      case 'generateOutline':
        await _showGenerateOutlineDialog();
        break;
      case 'expandOutlineNode':
        final outlineNode = ref.read(selectedOutlineNodeProvider);
        if (outlineNode == null) { _showOutlineHint(); return; }
        await _sendMessage(AiPrompts.expandOutlineNode(outlineNode.title, outlineNode.content ?? ''));
        break;
      case 'polishOutlineNode':
        final outlineNode2 = ref.read(selectedOutlineNodeProvider);
        if (outlineNode2 == null) { _showOutlineHint(); return; }
        await _sendMessage([
          '请润色以下大纲内容，使其更加清晰有条理、细节丰富、富有吸引力：',
          '',
          '标题：${outlineNode2.title}',
          outlineNode2.content != null && outlineNode2.content!.isNotEmpty ? '\n${outlineNode2.content}' : '',
        ].join('\n'));
        break;
      case 'generateChapterOutline':
        final outlineNode3 = ref.read(selectedOutlineNodeProvider);
        if (outlineNode3 == null) { _showOutlineHint(); return; }
        if (outlineNode3.type != 'chapter') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择一个「章」类型的大纲节点')));
          return;
        }
        await _sendMessage([
          '请根据以下大纲内容，为章节生成详细的章节细纲（5-8个场景）。',
          '',
          '章节标题：${outlineNode3.title}',
          outlineNode3.content != null && outlineNode3.content!.isNotEmpty ? '章节概要：\n${outlineNode3.content}\n' : '',
          '要求：',
          '1. 将章节拆分为 5-8 个场景/片段',
          '2. 每个场景给出核心内容、字数建议、爽点',
          '3. 确保场景之间有流畅过渡',
          '4. 标注开篇钩子和结尾悬念',
        ].join('\n'));
        break;
    }
  }

  void _showOutlineHint() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在大纲页面中选择一个节点'), duration: Duration(seconds: 2)),
      );
    }
  }

  // ===== 细纲扩写 =====
  Future<void> _showExpandOutlineDialog() async {
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择书籍')));
      return;
    }

    final chapterDao = ref.read(chapterDaoProvider);
    final outlineDao = ref.read(outlineDaoProvider);
    final volumeDao = ref.read(volumeDaoProvider);

    final volumes = await volumeDao.getVolumesByBook(bookId);
    final chaptersWithOutline = <_ChapterWithOutline>[];

    for (final vol in volumes) {
      final chapters = await chapterDao.getChaptersByVolume(vol.id);
      for (final ch in chapters) {
        final outlineNodes = await outlineDao.getOutlineNodesByChapter(ch.id);
        final outlineText = outlineNodes
            .where((n) => n.content != null && n.content!.isNotEmpty)
            .map((n) => '${n.title}：${n.content}')
            .join('\n\n');
        chaptersWithOutline.add(_ChapterWithOutline(
          chapter: ch,
          volumeTitle: vol.title,
          outlineText: outlineText,
        ));
      }
    }

    if (chaptersWithOutline.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无章节')));
      return;
    }

    _ChapterWithOutline? selectedChapter;
    final outlineCtrl = TextEditingController();

    final result = await showDialog<_ExpandOutlineData>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('细纲扩写'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择要扩写的章节细纲：', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<_ChapterWithOutline>(
                  value: selectedChapter,
                  decoration: const InputDecoration(
                    labelText: '章节',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: chaptersWithOutline.map((cwo) => DropdownMenuItem(
                    value: cwo,
                    child: Text('${cwo.volumeTitle} - ${cwo.chapter.title}', style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selectedChapter = v;
                        outlineCtrl.text = v.outlineText;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: outlineCtrl,
                  decoration: const InputDecoration(
                    labelText: '细纲内容（可编辑）',
                    hintText: '选中章节后自动带入大纲，可在此修改',
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: 8),
                const Text('将基于选中章节的上下文（前文摘要、角色设定）进行扩写', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (selectedChapter == null || outlineCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, _ExpandOutlineData(
                  chapter: selectedChapter!.chapter,
                  outlineText: outlineCtrl.text.trim(),
                ));
              },
              child: const Text('开始扩写'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final contextStr = await _buildContextForChapter(result.chapter.id, result.outlineText);
      await _sendMessage([
        '请根据以下细纲扩写成一篇完整的网文章节（约3000-4000字）。',
        '直接输出正文，不要加额外说明。',
        '',
        '细纲：',
        result.outlineText,
        contextStr,
      ].join('\n\n'));
    }
  }

  // ===== 起名面板（简化版，直接用对话框）=====
  Future<void> _showNamingPanel() async {
    if (!mounted) return;

    String surname = _namingSurname;
    String gender = _namingGender;
    String style = _namingStyle;
    int count = _namingCount;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('起名工具'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: _namingSurname),
                decoration: const InputDecoration(labelText: '姓氏（可选）', hintText: '如：叶、欧阳', isDense: true),
                onChanged: (v) => surname = v,
              ),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: '性别', isDense: true),
                items: [('male', '男性'), ('female', '女性'), ('neutral', '中性/不限')].map((g) => DropdownMenuItem(value: g.$1, child: Text(g.$2))).toList(),
                onChanged: (v) => gender = v!,
              ),
              DropdownButtonFormField<String>(
                value: style,
                decoration: const InputDecoration(labelText: '风格', isDense: true),
                items: [('xuanhuan', '玄幻'), ('xianxia', '仙侠'), ('wuxia', '武侠'), ('urban', '都市'), ('historical', '历史/架空'), ('scifi', '科幻')].map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                onChanged: (v) => style = v!,
              ),
              TextField(
                decoration: const InputDecoration(labelText: '生成数量', isDense: true),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _namingCount.toString()),
                onChanged: (v) => count = int.tryParse(v) ?? 15,
              ),
            ]),
          ),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成名字'),
              onPressed: () async {
                final config = await ref.read(aiConfigProvider.future);
                if (config.apiKey == null || config.apiKey!.isEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先配置 API Key')));
                  return;
                }

                final genderText = switch (gender) { 'male' => '男性', 'female' => '女性', _ => '中性/不限' };
                final styleText = switch (style) { 'xuanhuan' => '玄幻', 'xianxia' => '仙侠', 'wuxia' => '武侠', 'urban' => '都市', 'historical' => '历史/架空', 'scifi' => '科幻', _ => '古风' };
                final surnameText = surname.isNotEmpty ? '姓氏：$surname' : '姓氏：随机';
                final prompt = AiPrompts.naming('网文$styleText${switch (gender) { 'male' => '男性', 'female' => '女性', _ => '中性/不限' }}角色', style: '$surnameText，${styleText}风格，${switch (gender) { 'male' => '男性', 'female' => '女性', _ => '中性/不限' }}，每个名字2-4字，朗朗上口，有网文特色', count: count);

                setState(() => _isLoading = true);
                try {
                  final client = AiClient();
                  final response = await client.chat(provider: config.provider, apiKey: config.apiKey!, messages: [const AiMessage(role: 'system', content: AiPrompts.systemWriter), AiMessage(role: 'user', content: prompt)]);
                  final names = response.content.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('【') && !e.contains('生成') && !e.contains('名字')).take(count).toList();
                  if (mounted) { setState(() { _namingResults = names; _isLoading = false; }); }
                } catch (e) {
                  if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e'))); }
                }
              },
),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    ),
  );
}

  Future<void> _handleWriterBlock() async {
    final bookId = ref.read(selectedBookProvider);
    final chapterId = ref.read(selectedChapterProvider);

    String storyContext = '';
    String recentContent = '';

    if (bookId != null) {
      final outlineDao = ref.read(outlineDaoProvider);
      final characterDao = ref.read(characterDaoProvider);

      final bookOutlineNodes = await outlineDao.getOutlineByBook(bookId);
      if (bookOutlineNodes.isNotEmpty) {
        final outlineText = bookOutlineNodes
            .where((n) => n.content != null && n.content!.isNotEmpty)
            .map((n) => '${n.title}：${n.content}')
            .join('\n\n');
        storyContext += '【书籍大纲】\n$outlineText\n\n';
      }

      final characters = await characterDao.getCharactersByBook(bookId);
      if (characters.isNotEmpty) {
        final charText = characters
            .map((c) => '- ${c.name}（${c.roleType}）${c.personality != null && c.personality!.isNotEmpty ? " 性格：${c.personality}" : ""}')
            .join('\n');
        storyContext += '【角色设定】\n$charText\n\n';
      }
    }

    if (chapterId != null) {
      final chapterDao = ref.read(chapterDaoProvider);
      final chapter = await chapterDao.getChapterById(chapterId);
      if (chapter != null) {
        final outlineDao = ref.read(outlineDaoProvider);
        final chapterOutlines = await outlineDao.getOutlineNodesByChapter(chapterId);
        if (chapterOutlines.isNotEmpty) {
          final outlineText = chapterOutlines
              .where((n) => n.content != null && n.content!.isNotEmpty)
              .map((n) => '${n.title}：${n.content}')
              .join('\n\n');
          storyContext += '【当前章大纲】\n$outlineText\n\n';
        }

        final volumeDao = ref.read(volumeDaoProvider);
        final volumes = await volumeDao.getVolumesByBook(bookId!);
        final allChapters = <Chapter>[];
        for (final vol in volumes) {
          allChapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
        }
        allChapters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final currentIndex = allChapters.indexWhere((c) => c.id == chapterId);
        if (currentIndex > 0) {
          final recent = allChapters
              .sublist(max(0, currentIndex - 3), currentIndex)
              .map((c) => '【${c.title}】\n${c.content.length > 1500 ? c.content.substring(0, 1500) : c.content}')
              .join('\n\n---\n\n');
          recentContent = recent;
        }
      }
    }

    if (storyContext.isEmpty && recentContent.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先创建书籍和章节，或至少选择当前章节')));
      return;
    }

    final prompt = AiPrompts.writerBlock(recentContent, storyContext);
    await _sendMessage(prompt);
  }

  Future<String> _buildContextForChapter(String chapterId, String outlineText) async {
    final buffer = StringBuffer();
    final bookId = ref.read(selectedBookProvider);

    if (bookId != null) {
      final chapterDao = ref.read(chapterDaoProvider);
      final volumeDao = ref.read(volumeDaoProvider);
      final volumes = await volumeDao.getVolumesByBook(bookId);
      final allChapters = <Chapter>[];
      for (final vol in volumes) {
        allChapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
      }
      allChapters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final currentIndex = allChapters.indexWhere((c) => c.id == chapterId);
      if (currentIndex > 0) {
        final prevChapter = allChapters[currentIndex - 1];
        if (prevChapter.content.isNotEmpty) {
          buffer.writeln('【前一章摘要】');
          buffer.writeln(prevChapter.content.length > 2000 ? prevChapter.content.substring(0, 2000) : prevChapter.content);
          buffer.writeln();
        }
      }

      final characterDao = ref.read(characterDaoProvider);
      final characters = await characterDao.getCharactersByBook(bookId);
      if (characters.isNotEmpty) {
        buffer.writeln('【主要角色】');
        for (final c in characters.take(10)) {
          buffer.writeln('- ${c.name}（${c.roleType}）${c.personality != null && c.personality!.isNotEmpty ? " 性格：${c.personality}" : ""}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  Future<void> _handleBookPlanning() async {
    final bookId = ref.read(selectedBookProvider);
    String existingContent = '';

    // If book exists and has selected chapters, compress them first
    if (bookId != null) {
      final selectedIds = ref.read(selectedContextChaptersProvider);
      if (selectedIds.isNotEmpty) {
        final chapterDao = ref.read(chapterDaoProvider);
        final chapters = <Chapter>[];
        for (final id in selectedIds) {
          final ch = await chapterDao.getChapterById(id);
          if (ch != null) chapters.add(ch);
        }

        if (chapters.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在压缩章节摘要...'), duration: Duration(seconds: 1)),
          );

          final config = await ref.read(aiConfigProvider.future);
          if (config.apiKey != null && config.apiKey!.isNotEmpty) {
            final client = AiClient();
            final dao = ref.read(outlineDaoProvider);
            final service = ChapterCompressService(client, dao);
            final summaries = await service.compress(
              chapters: chapters,
              provider: config.provider,
              apiKey: config.apiKey!,
              bookId: bookId,
            );

            existingContent = summaries.map((s) => '${s.title}：${s.summary}').join('\n\n');
          }
        }
      }
    }

    if (!mounted) return;
    await _showBookPlanningDialog(existingContent);
  }

  Future<void> _showBookPlanningDialog(String existingContent) async {
    final conceptCtrl = TextEditingController();
    final genreCtrl = TextEditingController();
    final charactersCtrl = TextEditingController();
    final worldCtrl = TextEditingController();
    final targetCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新书规划'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('填写以下信息，AI 将生成一份完整的书籍创作规划。', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: conceptCtrl,
                  decoration: const InputDecoration(
                    labelText: '故事概念 *',
                    hintText: '如：一个现代程序员穿越到修仙世界，凭借编程思维开创全新修炼体系...',
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: genreCtrl,
                  decoration: const InputDecoration(
                    labelText: '小说类型/风格（可选）',
                    hintText: '玄幻/仙侠/都市/科幻，轻松/严肃/热血',
                    isDense: true,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: charactersCtrl,
                  decoration: const InputDecoration(
                    labelText: '主要角色（可选）',
                    hintText: '主角和重要配角的名字、定位',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: worldCtrl,
                  decoration: const InputDecoration(
                    labelText: '世界观设定（可选）',
                    hintText: '力量体系、势力分布、特殊规则',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  decoration: const InputDecoration(
                    labelText: '预计体量（可选）',
                    hintText: '如：100万字/3卷/50章',
                    isDense: true,
                  ),
                  maxLines: 1,
                ),
                if (existingContent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('已有章节摘要（自动生成）', style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        )),
                        const SizedBox(height: 4),
                        Text(existingContent, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (conceptCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('生成规划'),
          ),
        ],
      ),
    );

    final concept = conceptCtrl.text.trim();
    final genre = genreCtrl.text.trim();
    final characters = charactersCtrl.text.trim();
    final world = worldCtrl.text.trim();
    final target = targetCtrl.text.trim();
    conceptCtrl.dispose();
    genreCtrl.dispose();
    charactersCtrl.dispose();
    worldCtrl.dispose();
    targetCtrl.dispose();

    if (result == true && concept.isNotEmpty && mounted) {
      final prompt = AiPrompts.bookPlanning(
        storyConcept: concept,
        genre: genre,
        characters: characters,
        worldBuilding: world,
        targetLength: target,
        existingContent: existingContent,
      );
      await _sendMessage(prompt);
    }
  }

  Future<void> _showGenerateOutlineDialog() async {
    final conceptCtrl = TextEditingController();
    final charactersCtrl = TextEditingController();
    final worldCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 生成大纲'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('描述你的故事概念，AI 将生成完整的书籍级大纲。', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: conceptCtrl,
                decoration: const InputDecoration(
                  labelText: '故事概念 *',
                  hintText: '如：一个现代程序员穿越到修仙世界，凭借编程思维开创全新修炼体系...',
                  isDense: true,
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: charactersCtrl,
                decoration: const InputDecoration(
                  labelText: '主要角色（可选）',
                  hintText: '主角、重要配角的名字和定位',
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: worldCtrl,
                decoration: const InputDecoration(
                  labelText: '世界观设定（可选）',
                  hintText: '如：修炼等级体系、势力分布、特殊规则',
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (conceptCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('生成大纲'),
          ),
        ],
      ),
    );

    final concept = conceptCtrl.text.trim();
    final characters = charactersCtrl.text.trim();
    final world = worldCtrl.text.trim();
    conceptCtrl.dispose();
    charactersCtrl.dispose();
    worldCtrl.dispose();

    if (result == true && concept.isNotEmpty) {
      await _sendMessage(AiPrompts.generateOutline(concept, characters: characters, worldBuilding: world));
      if (mounted) {
        final messages = ref.read(aiChatMessagesProvider);
        final lastAssistantMsg = messages.where((m) => m.role == 'assistant').lastOrNull;
        if (lastAssistantMsg != null) {
          await _tryImportOutline(lastAssistantMsg.content);
        }
      }
    }
  }

  Future<void> _tryImportOutline(String aiResponse) async {
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null) return;

    String jsonStr = aiResponse.trim();

    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
    if (codeBlockMatch != null) {
      jsonStr = codeBlockMatch.group(1)!.trim();
    }

    final jsonStart = jsonStr.indexOf('[');
    if (jsonStart < 0) return;
    final jsonEnd = jsonStr.lastIndexOf(']');
    if (jsonEnd < 0) return;
    jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);

    List<dynamic> jsonList;
    try {
      jsonList = jsonDecode(jsonStr) as List<dynamic>;
    } catch (_) {
      return;
    }
    if (jsonList.isEmpty) return;

    final dao = ref.read(outlineDaoProvider);
    var rootNode = await dao.getBookRoot(bookId);
    if (rootNode == null) {
      // 首次导入：自动创建书籍大纲根节点，避免静默失败
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        bookId: Value(bookId),
        chapterId: const Value(''),
        parentId: const Value(null),
        title: const Value('书籍大纲'),
        content: const Value(null),
        sortOrder: const Value(0),
        type: const Value('book_root'),
        status: const Value('draft'),
      ));
      rootNode = await dao.getBookRoot(bookId);
      if (rootNode == null) return;
    }

    final companions = _jsonToCompanions(jsonList, bookId, rootNode.id);
    if (companions.isEmpty) return;

    if (!mounted) return;
    final totalNodes = companions.length;
    final volumes = companions.where((c) => c.type.value == 'volume').length;
    final chapters = companions.where((c) => c.type.value == 'chapter').length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入大纲'),
        content: Text('AI 生成了 $volumes 卷、$chapters 章，共 $totalNodes 个节点。\n是否导入到大纲编辑器？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await dao.insertOutlineNodes(companions);
      ref.read(outlineTreeRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 $totalNodes 个大纲节点'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  List<OutlineNodesCompanion> _jsonToCompanions(
    List<dynamic> jsonList, String bookId, String? parentId,
  ) {
    final result = <OutlineNodesCompanion>[];
    for (int i = 0; i < jsonList.length; i++) {
      final item = jsonList[i] as Map<String, dynamic>;
      final id = generateId();
      final title = item['title'] as String? ?? '';
      final type = item['type'] as String? ?? 'section';
      final content = item['content'] as String? ?? '';
      final children = item['children'] as List<dynamic>? ?? [];

      result.add(OutlineNodesCompanion(
        id: Value(id),
        bookId: Value(bookId),
        chapterId: const Value(''),
        parentId: Value(parentId),
        title: Value(title),
        content: Value(content.isEmpty ? null : content),
        sortOrder: Value(i),
        type: Value(type),
        status: const Value('draft'),
      ));

      if (children.isNotEmpty) {
        result.addAll(_jsonToCompanions(children, bookId, id));
      }
    }
    return result;
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

    // Build the tabbed content based on current tab
    Widget tabContent;
    switch (_tabController.index) {
      case 0:
        tabContent = _buildExpandOutlineTab(theme, fontFamily);
        break;
      case 1:
        tabContent = _buildNamingTab(theme, fontFamily);
        break;
      case 2:
        tabContent = _buildWriterBlockTab(theme, fontFamily);
        break;
      case 3:
      default:
        tabContent = _buildChatTab(theme, fontFamily);
        break;
    }

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildHeader(theme, fontFamily),
          const Divider(height: 1),
          // Tab bar
          Container(
            color: theme.colorScheme.surfaceContainerLow,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: fontFamily),
              unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, fontFamily: fontFamily),
              tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
              onTap: (index) {
                _tabController.animateTo(index);
                setState(() {}); // Trigger rebuild for tab-specific content
              },
),
          ),
          const Divider(height: 1),
          // Tab content with collapsible/Resizable panel
          Expanded(
            child: _aiPanelCollapsed
                ? const SizedBox.shrink()
                : _buildResizableTabPanel(
                    width: _aiPanelWidth,
                    minWidth: 280,
                    maxWidth: 520,
                    onResize: (w) => setState(() => _aiPanelWidth = w),
                    child: tabContent,
                  ),
          ),
          _buildCollapseHandle(
            collapsed: _aiPanelCollapsed,
            onToggle: () => setState(() => _aiPanelCollapsed = !_aiPanelCollapsed),
            isLeft: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String fontFamily) {
    final selectedCount = ref.watch(selectedContextChaptersProvider).length;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        const Text('AI 助手', style: TextStyle(fontWeight: FontWeight.w600)),
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
          onPressed: () => ref.read(aiChatMessagesProvider.notifier).clearAll(),
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
          ActionChip(avatar: const Icon(Icons.menu_book_outlined, size: 14), label: Text('新书规划', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('bookPlanning')),
          ActionChip(avatar: const Icon(Icons.auto_stories_outlined, size: 14), label: Text('细纲扩写', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('expand')),
          ActionChip(avatar: const Icon(Icons.abc_outlined, size: 14), label: Text('起名', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('naming')),
          ActionChip(avatar: const Icon(Icons.lightbulb_outline, size: 14), label: Text('卡文助手', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('writerBlock')),
          const SizedBox(width: 6),
          ActionChip(avatar: const Icon(Icons.auto_stories, size: 14), label: Text('拆书', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('analyzeBook')),
          ActionChip(avatar: const Icon(Icons.people_outline, size: 14), label: Text('人物', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('manageCharacters')),
          if (ref.watch(selectedOutlineNodeProvider) != null) ...[
            const SizedBox(width: 4),
            Container(width: 1, height: 20, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(width: 4),
            ActionChip(avatar: const Icon(Icons.auto_stories, size: 14), label: Text('生成大纲', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('generateOutline')),
            ActionChip(avatar: const Icon(Icons.open_in_full, size: 14), label: Text('扩写节点', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('expandOutlineNode')),
            ActionChip(avatar: const Icon(Icons.brush, size: 14), label: Text('润色节点', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('polishOutlineNode')),
            ActionChip(avatar: const Icon(Icons.list_alt, size: 14), label: Text('生成细纲', style: TextStyle(fontSize: 12, fontFamily: fontFamily)), onPressed: () => _quickAction('generateChapterOutline')),
          ],
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
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero),
                    child: const Text('清除', style: TextStyle(fontSize: 11)),
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
    final messages = ref.watch(aiChatMessagesProvider);
    if (messages.isEmpty && !_isLoading) {
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
      itemCount: messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final msg = messages[index];
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

  // ===== U1: Tabbed Panel Helpers =====

  Widget _buildResizableTabPanel({
    required double width,
    required double minWidth,
    required double maxWidth,
    required ValueChanged<double> onResize,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: child),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newWidth = (width + details.delta.dx).clamp(minWidth, maxWidth);
                onResize(newWidth);
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapseHandle({
    required bool collapsed,
    required VoidCallback onToggle,
    required bool isLeft,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 20,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Center(
          child: Icon(
            collapsed ? (isLeft ? Icons.chevron_right : Icons.chevron_left) : (isLeft ? Icons.chevron_left : Icons.chevron_right),
            size: 16, color: Colors.grey,
          ),
        ),
      ),
    );
  }

  // ===== Tab Content Placeholders (U2-U4) =====

  Widget _buildExpandOutlineTab(ThemeData theme, String fontFamily) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
          const SizedBox(height: 16),
          Text('细纲扩写', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, fontFamily: fontFamily)),
          const SizedBox(height: 8),
          Text('U2 实现中：左侧章节树 + 右侧全高编辑器 + 模版库', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120), fontFamily: fontFamily)),
        ],
      ),
    );
  }

  Widget _buildNamingTab(ThemeData theme, String fontFamily) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.abc_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
          const SizedBox(height: 16),
          Text('起名工具', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, fontFamily: fontFamily)),
          const SizedBox(height: 8),
          Text('U3 实现中：8大分类标签页 + 收藏夹 + 批量操作', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120), fontFamily: fontFamily)),
        ],
      ),
    );
  }

  Widget _buildWriterBlockTab(ThemeData theme, String fontFamily) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
          const SizedBox(height: 16),
          Text('卡文助手', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, fontFamily: fontFamily)),
          const SizedBox(height: 8),
          Text('U4 实现中：多路卡片流 + 迭代生成 + 上下文侧边栏', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120), fontFamily: fontFamily)),
        ],
      ),
    );
  }

  Widget _buildChatTab(ThemeData theme, String fontFamily) {
    // This is the existing chat functionality moved to a tab
    return Column(
      children: [
        if (_showChapterSelector) ...[
          const Divider(height: 1),
          _buildChapterSelector(theme, fontFamily),
        ],
        const Divider(height: 1),
        Expanded(child: _buildMessageList(theme, fontFamily)),
        const Divider(height: 1),
        _buildInputArea(theme, fontFamily),
      ],
    );
  }
}
