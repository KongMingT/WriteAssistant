import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/themes/theme_provider.dart';
import '../../../shared/widgets/undo_stack.dart';
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
  /// 超过该字数的章节被认定为"大章节"，加载时提示拆分
  static const int _largeChapterThreshold = 200000;

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String? _currentChapterId;
  bool _isLoading = false;
  bool _showOutline = true;
  DateTime? _sessionStart;
  int _sessionStartWordCount = 0;
  String? _activeSessionId;
  String? _lastSavedContent;
  String? _lastSavedTitle;
  Timer? _statusTimer;
  final _undoStack = UndoStack();
  Timer? _undoTimer;
  bool _isUndoingRedoing = false;

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
    await _saveImmediately();
  }

  @override
  void dispose() {
    _saveImmediately();
    _endSession();
    _contentController.dispose();
    _titleController.dispose();
    _statusTimer?.cancel();
    _saveDebounce?.cancel();
    _titleDebounce?.cancel();
    super.dispose();
  }

  Future<void> _saveImmediately() async {
    if (_currentChapterId == null) return;
    _saveDebounce?.cancel();
    final chapterDao = ref.read(chapterDaoProvider);
    final bookDao = ref.read(bookDaoProvider);
    final content = _contentController.text;
    final title = _titleController.text;
    if (content == _lastSavedContent && title == _lastSavedTitle) {
      return;
    }
    // 保存前先把当前已落库版本存为快照（版本回退用）
    if (_lastSavedContent != null) {
      final snapshotDao = ref.read(snapshotDaoProvider);
      await snapshotDao.createSnapshot(_currentChapterId!, _lastSavedTitle!, _lastSavedContent!);
    }
    await chapterDao.updateChapterContent(_currentChapterId!, content);
    await chapterDao.updateChapterTitle(_currentChapterId!, title);
    _lastSavedContent = content;
    _lastSavedTitle = title;
    final bookId = ref.read(selectedBookProvider);
    if (bookId != null) {
      await bookDao.recalculateBookWordCount(bookId);
    }
    ref.read(treeRefreshProvider.notifier).state++;
  }

  /// 版本历史对话框
  Future<void> _showHistoryDialog() async {
    final chapterId = _currentChapterId;
    if (chapterId == null) return;
    final snapshotDao = ref.read(snapshotDaoProvider);
    final snapshots = await snapshotDao.getSnapshots(chapterId);
    if (!mounted) return;

    if (snapshots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无历史版本（保存一次修改后自动记录）'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final picked = await showDialog<_RestoreTarget>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('历史版本'),
        content: SizedBox(
          width: 480,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: snapshots.length,
            itemBuilder: (_, i) {
              final s = snapshots[i];
              final time = DateFormat('MM-dd HH:mm').format(s.createdAt);
              final words = s.content.length;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text('${s.title}  ($words字)', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$time · 字数 $words'),
                trailing: const Icon(Icons.restore, size: 18),
                onTap: () => Navigator.pop(ctx, _RestoreTarget(s)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))],
      ),
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('恢复到「${picked.snapshot.title}」？'),
        content: const Text('恢复后当前未保存的改动将被覆盖，建议先复制备份。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _contentController.text = picked.snapshot.content;
    _titleController.text = picked.snapshot.title;
    _undoStack.clear();
    _undoStack.push(_contentController.value);
    _onContentChanged(picked.snapshot.content);
    await _saveImmediately();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复历史版本'), duration: Duration(seconds: 2)),
      );
    }
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
          const SizedBox(width: 12),
          Container(height: 18, width: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(width: 12),
          // 历史版本
          _toolButton(theme, Icons.history, '历史版本（保存修改时自动记录快照）', _showHistoryDialog),
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
            final ctrl = HardwareKeyboard.instance.isControlPressed;
            final shift = HardwareKeyboard.instance.isShiftPressed;
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              _insertTab();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter && !shift) {
              _insertNewlineWithIndent();
              return KeyEventResult.handled;
            }
            if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
              if (shift) { _redo(); } else { _undo(); }
              return KeyEventResult.handled;
            }
            if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
              _redo();
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
    if (!_isUndoingRedoing) {
      _undoTimer?.cancel();
      _undoTimer = Timer(const Duration(milliseconds: 300), () {
        _undoStack.push(_contentController.value);
      });
    }
  }

  // ===== 撤销/重做 =====

  void _undo() {
    _undoTimer?.cancel();
    final current = _contentController.value;
    final previous = _undoStack.undo(current);
    if (previous != null) {
      _isUndoingRedoing = true;
      _contentController.value = previous;
      _isUndoingRedoing = false;
    }
  }

  void _redo() {
    _undoTimer?.cancel();
    final current = _contentController.value;
    final next = _undoStack.redo(current);
    if (next != null) {
      _isUndoingRedoing = true;
      _contentController.value = next;
      _isUndoingRedoing = false;
    }
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
    await _saveImmediately();
    _endSession();
    setState(() => _isLoading = true);
    final chapterDao = ref.read(chapterDaoProvider);
    try {
      final chapter = await chapterDao.getChapterById(chapterId);
      if (chapter != null && mounted) {
        _contentController.text = chapter.content;
        _titleController.text = chapter.title;
        _lastSavedContent = chapter.content;
        _lastSavedTitle = chapter.title;
        _undoStack.clear();
        _undoStack.push(_contentController.value);
        setState(() {
          _currentChapterId = chapterId;
          _isLoading = false;
        });
        _startSession();
        _updateStatusBar();
        if (chapter.content.length > _largeChapterThreshold) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('⚠️ 本章共 ${chapter.content.length} 字，章节偏大可能导致编辑器卡顿，建议拆分为多个章节'),
                duration: const Duration(seconds: 4),
              ),
            );
        }
      }
    } catch (e) {
      // 章节加载失败时静默结束会话
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===== 写作会话（写入 writing_sessions） =====

  void _startSession() {
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null || _currentChapterId == null) return;
    final id = generateId();
    final sessionDao = ref.read(sessionDaoProvider);
    sessionDao.startSession(WritingSessionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(_currentChapterId),
      startTime: Value(DateTime.now()),
    ));
    _sessionStart = DateTime.now();
    _sessionStartWordCount = _contentController.text.length;
    _activeSessionId = id;
  }

  void _endSession() {
    final id = _activeSessionId;
    final startTime = _sessionStart;
    final startWords = _sessionStartWordCount;
    if (id == null || startTime == null) return;
    final now = DateTime.now();
    if (now.difference(startTime).inSeconds < 5) return;
    final written = (_contentController.text.length - startWords).clamp(0, 1 << 31);
    final sessionDao = ref.read(sessionDaoProvider);
    sessionDao.endSession(id, written);
    _activeSessionId = null;
    ref.read(writingStatsRefreshProvider.notifier).state++;
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
      final bookDao = ref.read(bookDaoProvider);
      final bookId = ref.read(selectedBookProvider);
      if (bookId != null) {
        await bookDao.recalculateBookWordCount(bookId);
      }
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
    final duration = hours > 0 ? '$hours时$mins分' : '$mins分';
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

/// 历史版本恢复目标
class _RestoreTarget {
  final ChapterSnapshot snapshot;
  const _RestoreTarget(this.snapshot);
}
