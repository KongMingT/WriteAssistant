import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/database/providers.dart';
import '../../../core/utils/id_generator.dart';
import '../models/selection_state.dart';

class ChapterTree extends ConsumerStatefulWidget {
  final String bookId;
  const ChapterTree({super.key, required this.bookId});

  @override
  ConsumerState<ChapterTree> createState() => _ChapterTreeState();
}

class _ChapterTreeState extends ConsumerState<ChapterTree> {
  List<Volume> _volumes = [];
  List<Chapter> _chapters = [];
  String? _selectedChapterId;
  bool _isLoading = true;
  int _lastRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenRequests());
  }

  void _listenRequests() {
    ref.listen<int>(newChapterRequestProvider, (prev, next) {
      if (prev != next) _createChapter();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(widget.bookId);
    final allChapters = <Chapter>[];
    for (final vol in volumes) {
      allChapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
    }
    if (mounted) {
      setState(() {
        _volumes = volumes;
        _chapters = allChapters;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectChapter(String chapterId) async {
    setState(() => _selectedChapterId = chapterId);
    ref.read(selectedChapterProvider.notifier).state = chapterId;
  }

  Future<void> _createChapter({String? inVolumeId}) async {
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
    await _loadData();
  }

  Future<void> _createVolume() async {
    final now = DateTime.now();
    final volumeDao = ref.read(volumeDaoProvider);
    await volumeDao.insertVolume(VolumesCompanion(
      id: Value(generateId()), bookId: Value(widget.bookId),
      title: Value('第${_volumes.length + 1}卷'),
      sortOrder: Value(_volumes.length), createdAt: Value(now),
    ));
    await _loadData();
  }

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

  Future<void> _deleteVolume(Volume vol) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分卷'),
        content: Text('确定删除「${vol.title}」吗？\n卷内所有章节也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirmed == true) {
      final volumeDao = ref.read(volumeDaoProvider);
      final chapterDao = ref.read(chapterDaoProvider);
      final volChapters = _chapters.where((c) => c.volumeId == vol.id);
      for (final ch in volChapters) {
        await chapterDao.deleteChapter(ch.id);
      }
      await volumeDao.deleteVolume(vol.id);
      if (mounted) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final refreshSignal = ref.watch(treeRefreshProvider);
    if (refreshSignal != _lastRefreshSignal) {
      _lastRefreshSignal = refreshSignal;
      Future.microtask(() => _loadData());
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
          else
            Expanded(child: _buildTree(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.list_alt_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('目录', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: '新建',
            onSelected: (v) {
              if (v == 'chapter') _createChapter();
              if (v == 'volume') _createVolume();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'volume', child: Text('新建分卷')),
              const PopupMenuItem(value: 'chapter', child: Text('新建章节')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTree(ThemeData theme) {
    if (_volumes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 8),
            Text('暂无章节', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _createChapter,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新建章节'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: _volumes.map((vol) => _buildVolumeWithChapters(vol, theme)).toList(),
    );
  }

  Widget _buildVolumeWithChapters(Volume vol, ThemeData theme) {
    final volChapters = _chapters.where((c) => c.volumeId == vol.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContextMenuRegion(
          items: [
            ContextMenuItem(label: '新建章节', icon: Icons.add, onTap: () => _createChapter(inVolumeId: vol.id)),
            ContextMenuItem(label: '重命名', icon: Icons.edit_outlined, onTap: () => _renameVolume(vol)),
            ContextMenuItem(label: '删除', icon: Icons.delete_outline, onTap: () => _deleteVolume(vol), isDestructive: true),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 12),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(vol.title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
              Text('${volChapters.length}章', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withAlpha(120))),
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
          padding: const EdgeInsets.only(left: 28, top: 4, bottom: 4, right: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(100) : null,
            border: isSelected ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 2)) : null,
          ),
          child: Row(children: [
            Icon(
              isSelected ? Icons.description : Icons.description_outlined,
              size: 14,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
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
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx + 1, details.globalPosition.dy + 1),
          items: items.map((item) => PopupMenuItem(
            onTap: item.onTap,
            child: Row(children: [
              Icon(item.icon, size: 16, color: item.isDestructive ? Colors.red : null),
              const SizedBox(width: 8),
              Text(item.label, style: item.isDestructive ? TextStyle(color: Colors.red) : null),
            ]),
          )).toList(),
        );
      },
      child: child,
    );
  }
}
