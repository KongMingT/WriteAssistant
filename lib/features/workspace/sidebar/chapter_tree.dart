import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';
import '../../../core/utils/id_generator.dart';
import '../models/selection_state.dart';

/// 左侧目录区 - 书籍→卷→章节树（支持右键菜单）
class ChapterTree extends ConsumerStatefulWidget {
  const ChapterTree({super.key});

  @override
  ConsumerState<ChapterTree> createState() => _ChapterTreeState();
}

class _ChapterTreeState extends ConsumerState<ChapterTree> {
  List<Book> _books = [];
  List<Volume> _volumes = [];
  List<Chapter> _chapters = [];
  String? _selectedBookId;
  String? _selectedChapterId;
  bool _isLoading = true;
  int _lastRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // 监听刷新信号
    final refreshSignal = ref.watch(treeRefreshProvider);
    // 信号变化时重新从DB加载章节数据
    if (refreshSignal != _lastRefreshSignal && _selectedBookId != null) {
      _lastRefreshSignal = refreshSignal;
      Future.microtask(() => _reloadCurrentBook());
    }

    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_books.isEmpty)
            _buildEmptyState(theme)
          else
            Expanded(child: _buildBookTree(theme)),
        ],
      ),
    );
  }

  // ===== 数据加载 =====

  Future<void> _loadData() async {
    final bookDao = ref.read(bookDaoProvider);
    final books = await bookDao.getAllBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
        if (books.isNotEmpty && _selectedBookId == null) {
          _selectBook(books.first.id);
        }
      });
    }
  }

  Future<void> _selectBook(String bookId) async {
    setState(() => _selectedBookId = bookId);
    ref.read(selectedBookProvider.notifier).state = bookId;
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
        _chapters = allChapters;
      });
    }
  }

  /// 重新加载当前选中书籍的卷和章节数据（用于同步标题变更）
  Future<void> _reloadCurrentBook() async {
    if (_selectedBookId == null) return;
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(_selectedBookId!);
    final allChapters = <Chapter>[];
    for (final vol in volumes) {
      allChapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
    }
    if (mounted) {
      setState(() {
        _volumes = volumes;
        _chapters = allChapters;
      });
    }
  }

  Future<void> _selectChapter(String chapterId) async {
    setState(() => _selectedChapterId = chapterId);
    ref.read(selectedChapterProvider.notifier).state = chapterId;
  }

  // ===== 新建 =====

  Future<void> _createBook() async {
    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建书籍'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: '书名', hintText: '输入书籍名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (result == true && titleController.text.isNotEmpty) {
      final now = DateTime.now();
      final bookId = generateId();
      final volId = generateId();
      final chapId = generateId();
      final bookDao = ref.read(bookDaoProvider);
      final volumeDao = ref.read(volumeDaoProvider);
      final chapterDao = ref.read(chapterDaoProvider);
      await bookDao.insertBook(BooksCompanion(
        id: Value(bookId), title: Value(titleController.text),
        createdAt: Value(now), updatedAt: Value(now),
      ));
      await volumeDao.insertVolume(VolumesCompanion(
        id: Value(volId), bookId: Value(bookId), title: const Value('第一卷'),
        sortOrder: const Value(0), createdAt: Value(now),
      ));
      await chapterDao.insertChapter(ChaptersCompanion(
        id: Value(chapId), volumeId: Value(volId), title: const Value('第一章'),
        content: const Value(''), sortOrder: const Value(0),
        createdAt: Value(now), updatedAt: Value(now),
      ));
      await _loadData();
      _selectChapter(chapId);
    }
    titleController.dispose();
  }

  Future<void> _createChapter({String? inVolumeId}) async {
    if (_selectedBookId == null) return;
    final now = DateTime.now();
    final chapterDao = ref.read(chapterDaoProvider);
    final targetVolId = inVolumeId ?? (_volumes.isNotEmpty ? _volumes.first.id : null);
    if (targetVolId == null) return;
    final count = _chapters.length;
    await chapterDao.insertChapter(ChaptersCompanion(
      id: Value(generateId()), volumeId: Value(targetVolId),
      title: Value('第${count + 1}章'), content: const Value(''),
      sortOrder: Value(count), createdAt: Value(now), updatedAt: Value(now),
    ));
    await _selectBook(_selectedBookId!);
  }

  Future<void> _createVolume() async {
    if (_selectedBookId == null) return;
    final now = DateTime.now();
    final volumeDao = ref.read(volumeDaoProvider);
    await volumeDao.insertVolume(VolumesCompanion(
      id: Value(generateId()), bookId: Value(_selectedBookId!),
      title: Value('第${_volumes.length + 1}卷'),
      sortOrder: Value(_volumes.length), createdAt: Value(now),
    ));
    await _selectBook(_selectedBookId!);
  }

  // ===== 重命名 =====

  Future<void> _renameChapter(Chapter chapter) async {
    final ctrl = TextEditingController(text: chapter.title);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名章节'), content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (result == true && ctrl.text.isNotEmpty) {
      final chapterDao = ref.read(chapterDaoProvider);
      await chapterDao.updateChapter(chapter.copyWith(title: ctrl.text));
      ref.read(treeRefreshProvider.notifier).state++;
    }
    ctrl.dispose();
  }

  Future<void> _renameVolume(Volume vol) async {
    final ctrl = TextEditingController(text: vol.title);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分卷'), content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (result == true && ctrl.text.isNotEmpty) {
      final volumeDao = ref.read(volumeDaoProvider);
      await volumeDao.updateVolume(vol.copyWith(title: ctrl.text));
      ref.read(treeRefreshProvider.notifier).state++;
    }
    ctrl.dispose();
  }

  Future<void> _renameBook(Book book) async {
    final ctrl = TextEditingController(text: book.title);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名书籍'), content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (result == true && ctrl.text.isNotEmpty) {
      final bookDao = ref.read(bookDaoProvider);
      await bookDao.updateBook(book.copyWith(title: ctrl.text));
      ref.read(treeRefreshProvider.notifier).state++;
    }
    ctrl.dispose();
  }

  // ===== 删除 =====

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除章节'),
        content: Text('确定删除「${chapter.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirmed == true) {
      final chapterDao = ref.read(chapterDaoProvider);
      await chapterDao.deleteChapter(chapter.id);
      ref.read(treeRefreshProvider.notifier).state++;
      if (mounted) _loadData();
    }
  }

  // ===== UI 构建 =====

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('目录', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: '新建',
            onSelected: (v) {
              if (v == 'book') _createBook();
              if (v == 'chapter') _createChapter();
              if (v == 'volume') _createVolume();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'book', child: Text('新建书籍')),
              if (_selectedBookId != null) ...[
                const PopupMenuItem(value: 'volume', child: Text('新建分卷')),
                const PopupMenuItem(value: 'chapter', child: Text('新建章节')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text('暂无书籍', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(onPressed: _createBook, icon: const Icon(Icons.add, size: 18), label: const Text('新建书籍')),
          ],
        ),
      ),
    );
  }

  Widget _buildBookTree(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: _books.map((book) => _buildBookItem(book, theme)).toList(),
    );
  }

  Widget _buildBookItem(Book book, ThemeData theme) {
    final isSelected = book.id == _selectedBookId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 书籍行（带右键菜单）
        _ContextMenuRegion(
          items: [
            ContextMenuItem(label: '新建分卷', icon: Icons.create_new_folder_outlined, onTap: () => _createVolume()),
            ContextMenuItem(label: '重命名', icon: Icons.edit_outlined, onTap: () => _renameBook(book)),
          ],
          child: InkWell(
            onTap: () { if (_selectedBookId != book.id) _selectBook(book.id); },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(isSelected ? Icons.book : Icons.book_outlined, size: 16,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(book.title, style: TextStyle(fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis)),
                Text('${book.wordCount}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
        if (isSelected && _volumes.isNotEmpty)
          ..._volumes.map((vol) => _buildVolumeWithChapters(vol, theme)),
      ],
    );
  }

  Widget _buildVolumeWithChapters(Volume vol, ThemeData theme) {
    final volChapters = _chapters.where((c) => c.volumeId == vol.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 卷行（带右键菜单）
        _ContextMenuRegion(
          items: [
            ContextMenuItem(label: '新建章节', icon: Icons.add, onTap: () => _createChapter(inVolumeId: vol.id)),
            ContextMenuItem(label: '重命名分卷', icon: Icons.edit_outlined, onTap: () => _renameVolume(vol)),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 28, top: 2, bottom: 2, right: 12),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(vol.title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
        ...volChapters.map((chap) => _buildChapterItem(chap, theme)),
      ],
    );
  }

  Widget _buildChapterItem(Chapter chapter, ThemeData theme) {
    final isSelected = chapter.id == _selectedChapterId;
    return _ContextMenuRegion(
      items: [
        ContextMenuItem(label: '重命名', icon: Icons.edit_outlined, onTap: () => _renameChapter(chapter)),
        ContextMenuItem(label: '删除', icon: Icons.delete_outline, onTap: () => _deleteChapter(chapter), isDestructive: true),
      ],
      child: InkWell(
        onTap: () => _selectChapter(chapter.id),
        child: Container(
          padding: const EdgeInsets.only(left: 44, top: 4, bottom: 4, right: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(100) : null,
            border: isSelected ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 2)) : null,
          ),
          child: Row(children: [
            Expanded(child: Text(chapter.title, style: TextStyle(fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis)),
            if (chapter.wordCount > 0)
              Text('${chapter.wordCount}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

// ===== 右键菜单组件 =====

class ContextMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  const ContextMenuItem({required this.label, required this.icon, required this.onTap, this.isDestructive = false});
}

class _ContextMenuRegion extends StatelessWidget {
  final List<ContextMenuItem> items;
  final Widget child;

  const _ContextMenuRegion({required this.items, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: child,
      onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: items.map((item) {
        return PopupMenuItem<String>(
          child: Row(children: [
            Icon(item.icon, size: 16, color: item.isDestructive ? Colors.red : null),
            const SizedBox(width: 8),
            Text(item.label, style: item.isDestructive ? const TextStyle(color: Colors.red) : null),
          ]),
          onTap: item.onTap,
        );
      }).toList(),
    );
  }
}
