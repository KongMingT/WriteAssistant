import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/providers.dart';
import '../../../shared/themes/theme_provider.dart';
import '../../outline/outline_panel.dart';
import '../models/selection_state.dart';

/// 编辑器工具栏字体列表
const _fontFamilies = {
  'SimSun': '宋体',
  'KaiTi': '楷体',
  'SimHei': '黑体',
  'Microsoft YaHei': '微软雅黑',
};

/// 章节编辑器（含工具栏）
class ChapterEditor extends ConsumerStatefulWidget {
  const ChapterEditor({super.key});

  @override
  ConsumerState<ChapterEditor> createState() => _ChapterEditorState();
}

class _ChapterEditorState extends ConsumerState<ChapterEditor> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String? _currentChapterId;
  bool _isLoading = false;
  bool _showOutline = true;
  DateTime? _sessionStart;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateStatusBar());
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForceSave());
  }

  void _listenForceSave() {
    ref.listen<int>(forceSaveProvider, (prev, next) {
      if (prev != next && _currentChapterId != null) {
        _doSaveNow();
      }
    });
  }

  Future<void> _doSaveNow() async {
    _saveDebounce?.cancel();
    if (_currentChapterId == null) return;
    final chapterDao = ref.read(chapterDaoProvider);
    await chapterDao.updateChapterContent(_currentChapterId!, _contentController.text);
    await chapterDao.updateChapterTitle(_currentChapterId!, _titleController.text);
    ref.read(treeRefreshProvider.notifier).state++;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _statusTimer?.cancel();
    _saveDebounce?.cancel();
    _titleDebounce?.cancel();
    super.dispose();
  }

  // ===== 缩进常量 =====
  static const _indentStr = '\u3000\u3000'; // 2个全角空格

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = ref.watch(editorFontSizeProvider);
    final fontFamily = ref.watch(editorFontFamilyProvider);
    final selectedChapterId = ref.watch(selectedChapterProvider);

    ref.listen<String?>(selectedChapterProvider, (prev, next) {
      if (next != null && next != _currentChapterId) _loadChapter(next);
    });
    if (_currentChapterId == null && selectedChapterId != null) {
      _loadChapter(selectedChapterId);
    }
    if (_currentChapterId == null) return _buildEmptyState(theme);

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // 编辑器工具栏（在标题上方）
          _buildToolbar(theme, fontSize, fontFamily),
          // 章节标题
          _buildTitleBar(theme),
          const Divider(height: 1),
          // 章纲面板
          if (_showOutline && _currentChapterId != null) ...[
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow.withAlpha(80),
                border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
              ),
              child: const OutlinePanel(),
            ),
            const Divider(height: 1),
          ],
          // 正文
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildEditor(theme, fontSize, fontFamily),
          ),
        ],
      ),
    );
  }

  // ===== 标题栏 =====

  Widget _buildTitleBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
      ),
      child: TextField(
        controller: _titleController,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (_) => _saveTitle(),
      ),
    );
  }

  // ===== 工具栏 =====

  static const _toolbarHeight = 36.0;

  Widget _buildToolbar(ThemeData theme, double fontSize, String fontFamily) {
    final displayFont = _fontFamilies[fontFamily] ?? fontFamily;

    return Container(
      height: _toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          // 字体选择
          _fontDropdown(theme, fontFamily, displayFont),
          const SizedBox(width: 12),
          Container(height: 18, width: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(width: 12),
          // 字号 + -
          _fontSizeControls(theme, fontSize),
          const SizedBox(width: 12),
          Container(height: 18, width: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(width: 12),
          // 缩进 + -
          _toolButton(theme, Icons.format_indent_increase, '增加缩进', _increaseIndent),
          const SizedBox(width: 4),
          _toolButton(theme, Icons.format_indent_decrease, '减少缩进', _decreaseIndent),
          const SizedBox(width: 12),
          Container(height: 18, width: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(width: 12),
          // 自动排版
          _toolButton(theme, Icons.auto_fix_high, '自动排版（全文加首行缩进）', _autoFormat),
          const SizedBox(width: 12),
          Container(height: 18, width: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(width: 12),
          // 大纲切换
          _toolButton(theme, _showOutline ? Icons.list_alt : Icons.list_alt_outlined, '显示/隐藏章纲', () => setState(() => _showOutline = !_showOutline)),
        ],
      ),
    );
  }

  Widget _fontDropdown(ThemeData theme, String current, String displayName) {
    return PopupMenuButton<String>(
      constraints: const BoxConstraints(minWidth: 120),
      tooltip: '选择字体',
      offset: const Offset(0, _toolbarHeight),
      onSelected: (v) => ref.read(editorFontFamilyProvider.notifier).setFamily(v),
      itemBuilder: (_) => _fontFamilies.entries
          .map((e) => PopupMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: TextStyle(fontFamily: e.key, fontSize: 13)),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayName, style: TextStyle(fontSize: 13, fontFamily: current, fontWeight: FontWeight.w500)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }

  Widget _fontSizeControls(ThemeData theme, double current) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolButton(theme, Icons.text_decrease, '缩小字号', _decreaseFontSize, iconSize: 16),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: Center(
            child: Text('${current.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 4),
        _toolButton(theme, Icons.text_increase, '增大字号', _increaseFontSize, iconSize: 16),
      ],
    );
  }

  Widget _toolButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onPressed, {double iconSize = 16}) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  // ===== 正文编辑区 =====

  Widget _buildEditor(ThemeData theme, double fontSize, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              _insertTab();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
              _insertNewlineWithIndent();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _contentController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(fontSize: fontSize, height: 1.8, fontFamily: fontFamily, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: '开始写作...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            contentPadding: const EdgeInsets.only(top: 12),
          ),
          onChanged: _onContentChanged,
        ),
      ),
    );
  }

  // ===== 内容变更 =====

  void _onContentChanged(String text) {
    _debounceSave(text);
    _updateStatusBar();
  }

  // ===== Tab键插入缩进 =====

  void _insertTab() {
    final text = _contentController.text;
    final start = _contentController.selection.start;
    final end = _contentController.selection.end;
    final newText = start == end
        ? '${text.substring(0, start)}$_indentStr${text.substring(start)}'
        : '${text.substring(0, start)}$_indentStr${text.substring(end)}';
    final cursor = start + _indentStr.length;
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _onContentChanged(newText);
  }

  // ===== 回车自动缩进 =====

  void _insertNewlineWithIndent() {
    final text = _contentController.text;
    final pos = _contentController.selection.start;
    if (pos < 0) return;
    final prevNewline = text.lastIndexOf('\n', pos - 1);
    final lineStart = prevNewline + 1;
    final line = prevNewline < 0 ? text.substring(0, pos) : text.substring(lineStart, pos);
    String indent = '';
    for (int i = 0; i < line.length && line[i] == '\u3000'; i++) {
      indent += '\u3000';
    }
    indent = indent.substring(0, (indent.length ~/ 2) * 2);
    final insertion = '\n$indent';
    final newText = '${text.substring(0, pos)}$insertion${text.substring(pos)}';
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + insertion.length),
    );
    _onContentChanged(newText);
  }

  // ===== 工具栏操作 =====

  void _increaseIndent() {
    final text = _contentController.text;
    if (text.isEmpty) return;
    final sel = _contentController.selection;
    if (sel.isValid && !sel.isCollapsed) {
      // 多行选中：给所有选中行加缩进
      final startLine = text.lastIndexOf('\n', sel.start - 1) + 1;
      final endLine = text.indexOf('\n', sel.end);
      final end = endLine < 0 ? text.length : endLine;
      final selected = text.substring(startLine, end);
      final indented = selected.split('\n').map((line) {
        if (line.isEmpty) return line;
        return _indentStr + line;
      }).join('\n');
      final newText = '${text.substring(0, startLine)}$indented${text.substring(end)}';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: startLine, extentOffset: startLine + indented.length),
      );
      _onContentChanged(newText);
    } else {
      final start = sel.start;
      final paraStart = text.lastIndexOf('\n', start - 1) + 1;
      final newText = '${text.substring(0, paraStart)}$_indentStr${text.substring(paraStart)}';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + _indentStr.length),
      );
      _onContentChanged(newText);
    }
  }

  void _decreaseIndent() {
    final text = _contentController.text;
    if (text.isEmpty) return;
    final sel = _contentController.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final startLine = text.lastIndexOf('\n', sel.start - 1) + 1;
      final endLine = text.indexOf('\n', sel.end);
      final end = endLine < 0 ? text.length : endLine;
      final selected = text.substring(startLine, end);
      final deindented = selected.split('\n').map((line) {
        if (line.startsWith(_indentStr)) return line.substring(2);
        if (line.startsWith('\u3000')) return line.substring(1);
        return line;
      }).join('\n');
      final newText = '${text.substring(0, startLine)}$deindented${text.substring(end)}';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: startLine, extentOffset: startLine + deindented.length),
      );
      _onContentChanged(newText);
    } else {
      final start = sel.start;
      final paraStart = text.lastIndexOf('\n', start - 1) + 1;
      final linePart = text.substring(paraStart);
      if (linePart.startsWith(_indentStr)) {
        final newText = '${text.substring(0, paraStart)}${linePart.substring(2)}';
        final newOffset = (start - 2).clamp(paraStart, newText.length);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
        _onContentChanged(newText);
      } else if (linePart.startsWith('\u3000')) {
        final newText = '${text.substring(0, paraStart)}${linePart.substring(1)}';
        final newOffset = (start - 1).clamp(paraStart, newText.length);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
        _onContentChanged(newText);
      }
    }
  }

  void _autoFormat() {
    final lines = _contentController.text.split('\n');
    final formatted = lines.map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) return '';
      if (line.startsWith(_indentStr) || line.startsWith('\u3000')) return line;
      return '$_indentStr$trimmed';
    }).join('\n');
    if (formatted != _contentController.text) {
      _contentController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _onContentChanged(formatted);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 全文已自动缩进排版'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _increaseFontSize() {
    final current = ref.read(editorFontSizeProvider);
    if (current < 32) ref.read(editorFontSizeProvider.notifier).setSize(current + 1);
  }

  void _decreaseFontSize() {
    final current = ref.read(editorFontSizeProvider);
    if (current > 12) ref.read(editorFontSizeProvider.notifier).setSize(current - 1);
  }

  // ===== 数据加载 =====

  Future<void> _loadChapter(String chapterId) async {
    setState(() => _isLoading = true);
    final chapterDao = ref.read(chapterDaoProvider);
    final chapter = await chapterDao.getChapterById(chapterId);
    if (chapter != null && mounted) {
      _contentController.text = chapter.content;
      _titleController.text = chapter.title;
      setState(() { _currentChapterId = chapterId; _isLoading = false; });
      _sessionStart = DateTime.now();
      _updateStatusBar();
    }
  }

  // ===== 标题保存 =====

  Timer? _titleDebounce;
  Future<void> _saveTitle() async {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (_currentChapterId == null) return;
      final chapterDao = ref.read(chapterDaoProvider);
      await chapterDao.updateChapterTitle(_currentChapterId!, _titleController.text);
      ref.read(treeRefreshProvider.notifier).state++;
    });
  }

  // ===== 内容自动保存(防抖) =====

  Timer? _saveDebounce;
  void _debounceSave(String text) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), () async {
      if (_currentChapterId == null) return;
      final chapterDao = ref.read(chapterDaoProvider);
      await chapterDao.updateChapterContent(_currentChapterId!, text);
    });
  }

  // ===== 状态栏 =====

  void _updateStatusBar() {
    final wordCount = _contentController.text.length;
    if (_sessionStart == null) {
      ref.read(writingStateProvider.notifier).state = WritingState(wordCount: wordCount);
      return;
    }
    final elapsed = DateTime.now().difference(_sessionStart!);
    final minutes = elapsed.inMinutes;
    final speed = minutes > 0 ? (wordCount ~/ minutes) * 60 : 0;
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes % 60;
    final duration = hours > 0 ? '$hours时${mins}分' : '$mins分';
    ref.read(writingStateProvider.notifier).state = WritingState(wordCount: wordCount, writingSpeed: speed, sessionDuration: duration);
  }

  // ===== 空状态 =====

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 64, color: theme.colorScheme.primary.withAlpha(60)),
            const SizedBox(height: 16),
            Text('选择或新建一个章节开始写作', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
