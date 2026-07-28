import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../book_analysis/book_analysis_screen.dart';
import '../character/character_sheet.dart';
import '../outline/outline_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/services/txt_export_service.dart';
import '../../shared/widgets/status_bar.dart';
import 'ai_panel/ai_panel.dart';
import 'editor/chapter_editor.dart';
import 'models/selection_state.dart';
import 'sidebar/chapter_tree.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  final String bookId;
  const WorkspaceScreen({super.key, required this.bookId});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  double _sidebarWidth = 250;
  double _aiPanelWidth = 300;
  bool _sidebarCollapsed = false;
  bool _aiPanelCollapsed = false;
  final _focusNode = FocusNode();
  String _bookTitle = '';

  @override
  void initState() {
    super.initState();
    ref.read(selectedBookProvider.notifier).state = widget.bookId;
    ref.read(selectedChapterProvider.notifier).state = null;
    _loadBookTitle();
    _selectLatestChapter();
  }

  Future<void> _loadBookTitle() async {
    final bookDao = ref.read(bookDaoProvider);
    final book = await bookDao.getBookById(widget.bookId);
    if (mounted && book != null) setState(() => _bookTitle = book.title);
  }

  Future<void> _selectLatestChapter() async {
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(widget.bookId);
    Chapter? latest;
    for (final vol in volumes) {
      final chapters = await chapterDao.getChaptersByVolume(vol.id);
      for (final ch in chapters) {
        if (latest == null || ch.sortOrder > latest.sortOrder) {
          latest = ch;
        }
      }
    }
    if (latest != null && mounted) {
      ref.read(selectedChapterProvider.notifier).state = latest.id;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (!ctrl) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyS:
        ref.read(forceSaveProvider.notifier).state++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyE:
        _exportCurrentChapter();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyN:
        if (HardwareKeyboard.instance.isShiftPressed) {
          ref.read(newBookRequestProvider.notifier).state++;
        } else {
          ref.read(newChapterRequestProvider.notifier).state++;
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _showCharacterSheet() {
    showCharacterSheet(context, ref);
  }

  Future<void> _exportCurrentChapter() async {
    final chapterId = ref.read(selectedChapterProvider);
    if (chapterId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择一个章节')));
      return;
    }
    final chapterDao = ref.read(chapterDaoProvider);
    final chapter = await chapterDao.getChapterById(chapterId);
    if (chapter == null) return;

    final exportService = TxtExportService();
    final dir = await exportService.pickExportDirectory();
    if (dir == null || !mounted) return;

    await exportService.exportChapter(dir, chapter.title, chapter.content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出: ${chapter.title}.txt'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _exportAllChapters() async {
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final bookDao = ref.read(bookDaoProvider);
    final book = await bookDao.getBookById(widget.bookId);
    if (book == null) return;

    final exportService = TxtExportService();
    final dir = await exportService.pickExportDirectory();
    if (dir == null || !mounted) return;

    final volumes = await volumeDao.getVolumesByBook(widget.bookId);
    final chapters = <({String title, String content})>[];
    for (final vol in volumes) {
      final volChapters = await chapterDao.getChaptersByVolume(vol.id);
      for (final ch in volChapters) {
        chapters.add((title: ch.title, content: ch.content));
      }
    }

    await exportService.exportBook(dir, book.title, chapters);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出: ${book.title}.txt (${chapters.length}章)'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (!_sidebarCollapsed)
                    _buildResizablePanel(
                      width: _sidebarWidth, minWidth: 180, maxWidth: 400,
                      onResize: (w) => setState(() => _sidebarWidth = w),
                      child: ChapterTree(bookId: widget.bookId),
                    ),
                  _buildCollapseHandle(
                    collapsed: _sidebarCollapsed,
                    onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    isLeft: true,
                  ),
                  const Expanded(child: ChapterEditor()),
                  _buildCollapseHandle(
                    collapsed: _aiPanelCollapsed,
                    onToggle: () => setState(() => _aiPanelCollapsed = !_aiPanelCollapsed),
                    isLeft: false,
                  ),
                  if (!_aiPanelCollapsed)
                    _buildResizablePanel(
                      width: _aiPanelWidth, minWidth: 250, maxWidth: 500,
                      onResize: (w) => setState(() => _aiPanelWidth = w),
                      child: const AiPanel(),
                    ),
                ],
              ),
            ),
            const StatusBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回书籍列表',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(_bookTitle.isEmpty ? '加载中...' : _bookTitle),
      centerTitle: false,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导出',
          onSelected: (v) {
            if (v == 'chapter') _exportCurrentChapter();
            if (v == 'book') _exportAllChapters();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'chapter', child: Text('导出当前章节')),
            const PopupMenuItem(value: 'book', child: Text('导出整本书')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.account_tree_outlined),
          tooltip: '书籍大纲',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OutlineScreen(bookId: widget.bookId))),
        ),
        IconButton(
          icon: const Icon(Icons.people_outlined),
          tooltip: '人物管理',
          onPressed: _showCharacterSheet,
        ),
        IconButton(
          icon: const Icon(Icons.auto_stories_outlined),
          tooltip: '拆书分析',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookAnalysisScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }

  Widget _buildResizablePanel({
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
                final newWidth = width + details.delta.dx;
                onResize(newWidth.clamp(minWidth, maxWidth));
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
            collapsed
                ? (isLeft ? Icons.chevron_right : Icons.chevron_left)
                : (isLeft ? Icons.chevron_left : Icons.chevron_right),
            size: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
