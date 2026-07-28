import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/utils/id_generator.dart';
import '../workspace/ai_panel/ai_panel.dart';
import '../workspace/models/selection_state.dart';

class OutlineScreen extends ConsumerStatefulWidget {
  final String bookId;
  const OutlineScreen({super.key, required this.bookId});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  double _treeWidth = 250;
  double _aiPanelWidth = 300;
  bool _treeCollapsed = false;
  bool _aiPanelCollapsed = false;
  String _bookTitle = '';

  // Tree data
  OutlineNode? _rootNode;
  final Set<String> _expandedIds = {};
  final Map<String, List<OutlineNode>> _childCache = {};
  bool _treeLoading = true;

  // Editor data
  OutlineNode? _editingNode;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  Timer? _titleTimer;
  Timer? _contentTimer;

  // All chapters for link dropdown
  List<Chapter> _allChapters = [];
  int _lastRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    ref.read(selectedBookProvider.notifier).state = widget.bookId;
    ref.read(selectedOutlineNodeProvider.notifier).state = null;
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleTimer?.cancel();
    _contentTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadBookInfo(), _loadChapters(), _loadRootNode()]);
  }

  Future<void> _loadBookInfo() async {
    final bookDao = ref.read(bookDaoProvider);
    final book = await bookDao.getBookById(widget.bookId);
    if (mounted && book != null) setState(() => _bookTitle = book.title);
  }

  Future<void> _loadChapters() async {
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(widget.bookId);
    final chapters = <Chapter>[];
    for (final vol in volumes) {
      chapters.addAll(await chapterDao.getChaptersByVolume(vol.id));
    }
    if (mounted) setState(() { _allChapters = chapters; });
  }

  Future<void> _loadRootNode() async {
    setState(() => _treeLoading = true);
    final dao = ref.read(outlineDaoProvider);
    var root = await dao.getBookRoot(widget.bookId);
    if (root == null) {
      final id = generateId();
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(id),
        bookId: Value(widget.bookId),
        chapterId: const Value(''),
        parentId: const Value(null),
        title: Value(_bookTitle.isEmpty ? '书籍大纲' : _bookTitle),
        content: const Value(null),
        sortOrder: const Value(0),
        type: const Value('book_root'),
        status: const Value('draft'),
      ));
      root = await dao.getBookRoot(widget.bookId);
    }
    if (root != null) {
      await _loadChildren(root.id);
    }
    if (mounted) setState(() { _rootNode = root; _treeLoading = false; });
  }

  Future<List<OutlineNode>> _loadChildren(String parentId) async {
    final dao = ref.read(outlineDaoProvider);
    final children = await dao.getOutlineNodesByParent(parentId);
    _childCache[parentId] = children;
    return children;
  }

  List<_FlatNode> _buildFlatList() {
    final items = <_FlatNode>[];
    void traverse(OutlineNode node, int depth) {
      final children = _childCache[node.id] ?? [];
      items.add(_FlatNode(node: node, depth: depth, hasChildren: children.isNotEmpty));
      if (_expandedIds.contains(node.id)) {
        for (final child in children) {
          traverse(child, depth + 1);
        }
      }
    }
    if (_rootNode != null) traverse(_rootNode!, 0);
    return items;
  }

  // ===== Editor =====

  void _selectNode(OutlineNode node) {
    _saveCurrentEditor();
    setState(() {
      _editingNode = node;
      _titleCtrl.text = node.title;
      _contentCtrl.text = node.content ?? '';
    });
    ref.read(selectedOutlineNodeProvider.notifier).state = node;
  }

  void _saveCurrentEditor() {
    if (_editingNode == null) return;
    _titleTimer?.cancel();
    _contentTimer?.cancel();
    _doSaveNode(_editingNode!, _titleCtrl.text, _contentCtrl.text);
  }

  Future<void> _doSaveNode(OutlineNode node, String title, String content) async {
    final dao = ref.read(outlineDaoProvider);
    final now = DateTime.now();
    final updated = node.copyWith(
      title: title,
      content: Value(content.isEmpty ? null : content),
      updatedAt: Value(now),
    );
    await dao.updateOutlineNode(updated);
    if (mounted) {
      setState(() {
        _editingNode = updated;
        if (node.id == _rootNode?.id) _rootNode = updated;
        _updateNodeInCache(updated);
      });
    }
  }

  void _updateNodeInCache(OutlineNode updated) {
    for (final parentId in _childCache.keys) {
      final idx = _childCache[parentId]!.indexWhere((n) => n.id == updated.id);
      if (idx >= 0) {
        _childCache[parentId]![idx] = updated;
        break;
      }
    }
  }

  void _onTitleChanged(String text) {
    _titleTimer?.cancel();
    _titleTimer = Timer(const Duration(milliseconds: 500), () {
      if (_editingNode != null) _doSaveNode(_editingNode!, text, _contentCtrl.text);
    });
  }

  void _onContentChanged(String text) {
    _contentTimer?.cancel();
    _contentTimer = Timer(const Duration(seconds: 3), () {
      if (_editingNode != null) _doSaveNode(_editingNode!, _titleCtrl.text, text);
    });
  }

  // ===== Node Operations =====

  Future<void> _addChildNode(OutlineNode parent) async {
    final validTypes = _validChildTypes(parent.type);
    if (validTypes.isEmpty) return;

    final result = await showDialog<_AddNodeData>(
      context: context,
      builder: (_) => _AddNodeDialog(
        parentTitle: parent.title,
        validTypes: validTypes,
        defaultType: validTypes.first,
      ),
    );
    if (result == null || !mounted) return;

    final children = _childCache[parent.id] ?? [];
    final dao = ref.read(outlineDaoProvider);
    await dao.insertOutlineNode(OutlineNodesCompanion(
      id: Value(generateId()),
      bookId: Value(widget.bookId),
      chapterId: const Value(''),
      parentId: Value(parent.id),
      title: Value(result.title),
      content: Value(result.content.isEmpty ? null : result.content),
      sortOrder: Value(children.length),
      type: Value(result.type),
      status: const Value('draft'),
    ));
    await _loadChildren(parent.id);
    if (!_expandedIds.contains(parent.id)) {
      setState(() => _expandedIds.add(parent.id));
    }
    setState(() {});
  }

  Future<void> _addSiblingNode(OutlineNode node) async {
    if (node.parentId == null || node.parentId!.isEmpty) return;
    final parentChildren = _childCache[node.parentId] ?? [];
    final parentNode = _findNodeById(node.parentId!);
    if (parentNode == null) return;

    final validTypes = _validChildTypes(parentNode.type);
    final result = await showDialog<_AddNodeData>(
      context: context,
      builder: (_) => _AddNodeDialog(
        parentTitle: parentNode.title,
        validTypes: validTypes,
        defaultType: node.type,
      ),
    );
    if (result == null || !mounted) return;

    final dao = ref.read(outlineDaoProvider);
    await dao.insertOutlineNode(OutlineNodesCompanion(
      id: Value(generateId()),
      bookId: Value(widget.bookId),
      chapterId: const Value(''),
      parentId: Value(node.parentId),
      title: Value(result.title),
      content: Value(result.content.isEmpty ? null : result.content),
      sortOrder: Value(parentChildren.length),
      type: Value(result.type),
      status: const Value('draft'),
    ));
    await _loadChildren(node.parentId!);
    setState(() {});
  }

  Future<void> _deleteNode(OutlineNode node) async {
    if (node.type == 'book_root') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能删除根节点'), duration: Duration(seconds: 1)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除大纲节点'),
        content: Text('确定删除「${node.title}」吗？\n所有子节点也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _deleteNodeRecursive(node.id);

    if (_editingNode?.id == node.id) {
      setState(() { _editingNode = null; _titleCtrl.text = ''; _contentCtrl.text = ''; });
      ref.read(selectedOutlineNodeProvider.notifier).state = null;
    }
    final parentId = node.parentId;
    if (parentId != null && parentId.isNotEmpty) {
      await _loadChildren(parentId);
    }
    setState(() {});
  }

  Future<void> _deleteNodeRecursive(String nodeId) async {
    final children = _childCache[nodeId] ?? [];
    for (final child in children) {
      await _deleteNodeRecursive(child.id);
    }
    _childCache.remove(nodeId);
    _expandedIds.remove(nodeId);
    final dao = ref.read(outlineDaoProvider);
    await dao.deleteOutlineNode(nodeId);
  }

  OutlineNode? _findNodeById(String id) {
    if (_rootNode?.id == id) return _rootNode;
    for (final list in _childCache.values) {
      for (final n in list) {
        if (n.id == id) return n;
      }
    }
    return null;
  }

  Future<void> _toggleExpand(OutlineNode node) async {
    if (_expandedIds.contains(node.id)) {
      setState(() => _expandedIds.remove(node.id));
    } else {
      if (_childCache[node.id] == null) {
        await _loadChildren(node.id);
      }
      setState(() => _expandedIds.add(node.id));
    }
  }

  // ===== Helpers =====

  IconData _typeIcon(String type) {
    switch (type) {
      case 'book_root': return Icons.menu_book;
      case 'volume': return Icons.folder_outlined;
      case 'chapter': return Icons.description_outlined;
      case 'section': return Icons.article_outlined;
      case 'beat': return Icons.bolt;
      default: return Icons.circle;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'book_root': return '书籍';
      case 'volume': return '卷';
      case 'chapter': return '章';
      case 'section': return '节';
      case 'beat': return '剧情点';
      default: return type;
    }
  }

  List<String> _validChildTypes(String parentType) {
    switch (parentType) {
      case 'book_root': return ['volume'];
      case 'volume': return ['chapter'];
      case 'chapter': return ['section', 'beat'];
      case 'section': return ['beat'];
      case 'beat': return ['section', 'beat'];
      default: return [];
    }
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    final refreshSignal = ref.watch(outlineTreeRefreshProvider);
    if (refreshSignal != _lastRefreshSignal) {
      _lastRefreshSignal = refreshSignal;
      Future.microtask(() => _loadRootNode());
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (!_treeCollapsed)
                  _buildResizablePanel(
                    width: _treeWidth, minWidth: 200, maxWidth: 400,
                    onResize: (w) => setState(() => _treeWidth = w),
                    child: _buildTreePanel(),
                  ),
                _buildCollapseHandle(
                  collapsed: _treeCollapsed,
                  onToggle: () => setState(() => _treeCollapsed = !_treeCollapsed),
                  isLeft: true,
                ),
                Expanded(child: _buildEditorPanel()),
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
          _buildStatusBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回工作区',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('《$_bookTitle》- 大纲管理'),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: '保存当前节点',
          onPressed: () { _saveCurrentEditor(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1))); },
        ),
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导出大纲',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出功能待实现'), duration: Duration(seconds: 1)));
          },
        ),
      ],
    );
  }

  // ===== Tree Panel =====

  Widget _buildTreePanel() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _buildTreeHeader(theme),
          const Divider(height: 1),
          if (_treeLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_rootNode == null)
            const Expanded(child: Center(child: Text('加载失败')))
          else
            Expanded(child: _buildTreeList(theme)),
        ],
      ),
    );
  }

  Widget _buildTreeHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.account_tree_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        const Text('大纲结构', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 16),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          tooltip: '操作',
          onSelected: (v) {
            if (v == 'expandAll') _expandAll();
            if (v == 'collapseAll') setState(() => _expandedIds.clear());
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'expandAll', child: Text('展开全部')),
            const PopupMenuItem(value: 'collapseAll', child: Text('折叠全部')),
          ],
        ),
      ]),
    );
  }

  void _expandAll() {
    for (final parentId in _childCache.keys) {
      _expandedIds.add(parentId);
    }
    setState(() {});
  }

  Widget _buildTreeList(ThemeData theme) {
    final flatList = _buildFlatList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: flatList.length,
      itemBuilder: (_, i) => _buildTreeItem(flatList[i], theme),
    );
  }

  Widget _buildTreeItem(_FlatNode item, ThemeData theme) {
    final node = item.node;
    final isSelected = _editingNode?.id == node.id;
    final isExpanded = _expandedIds.contains(node.id);
    final isRoot = node.type == 'book_root';

    return _ContextMenuRegion(
      items: [
        if (!isRoot) ContextMenuItem(label: '添加子节点', icon: Icons.add, onTap: () => _addChildNode(node)),
        if (!isRoot && node.parentId != null && node.parentId!.isNotEmpty)
          ContextMenuItem(label: '添加同级', icon: Icons.add_circle_outline, onTap: () => _addSiblingNode(node)),
        if (!isRoot)
          ContextMenuItem(label: '删除', icon: Icons.delete_outline, onTap: () => _deleteNode(node), isDestructive: true),
      ],
      child: InkWell(
        onTap: () => _selectNode(node),
        child: Container(
          padding: EdgeInsets.only(left: 12.0 + item.depth * 16, top: 4, bottom: 4, right: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(100) : null,
            border: isSelected ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 2)) : null,
          ),
          child: Row(children: [
            if (item.hasChildren)
              InkWell(
                onTap: () => _toggleExpand(node),
                child: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 14, color: theme.colorScheme.onSurfaceVariant),
              )
            else
              const SizedBox(width: 14),
            const SizedBox(width: 2),
            Icon(_typeIcon(node.type), size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                node.title,
                style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (node.status == 'final')
              Icon(Icons.check_circle, size: 12, color: theme.colorScheme.primary.withAlpha(120)),
          ]),
        ),
      ),
    );
  }

  // ===== Editor Panel =====

  Widget _buildEditorPanel() {
    final theme = Theme.of(context);

    if (_editingNode == null) {
      return Container(
        color: theme.colorScheme.surface,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_tree_outlined, size: 64, color: theme.colorScheme.primary.withAlpha(60)),
            const SizedBox(height: 16),
            Text('选择左侧大纲节点进行编辑', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
          ]),
        ),
      );
    }

    final node = _editingNode!;
    final wordCount = (node.title.length) + (node.content?.length ?? 0);

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_typeLabel(node.type), style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 8),
              Text('$wordCount 字', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: node.status == 'final'
                      ? Colors.green.withAlpha(30)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.status == 'final' ? '已定稿' : '草稿',
                  style: TextStyle(fontSize: 11, color: node.status == 'final' ? Colors.green : theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              if (node.type == 'chapter')
                PopupMenuButton<String>(
                  tooltip: '关联章节',
                  constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
                  offset: const Offset(0, 24),
                  onSelected: (chapterId) {
                    _doSaveNode(node, _titleCtrl.text, _contentCtrl.text);
                    final dao = ref.read(outlineDaoProvider);
                    final now = DateTime.now();
                    dao.updateOutlineNode(node.copyWith(chapterId: chapterId, updatedAt: Value(now)));
                  },
                  itemBuilder: (_) => _allChapters.map((ch) => PopupMenuItem(
                    value: ch.id,
                    child: Text(ch.title, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        node.chapterId.isNotEmpty ? (_allChapters.where((c) => c.id == node.chapterId).firstOrNull?.title ?? '已关联') : '关联章节',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
          const Divider(height: 1),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: TextField(
              controller: _titleCtrl,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '节点标题',
              ),
              onChanged: _onTitleChanged,
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: node.type == 'book_root'
                      ? '书籍简介、核心设定、世界观概述...'
                      : node.type == 'volume'
                          ? '本卷概述、核心冲突、主要剧情线...'
                          : node.type == 'chapter'
                              ? '本章核心内容、主要情节、关键场景...'
                              : node.type == 'beat'
                                  ? '具体剧情节点的详细描述...'
                                  : '节点详细内容...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onContentChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Status Bar =====

  Widget _buildStatusBar() {
    final theme = Theme.of(context);
    int totalNodes = 0;
    int finalNodes = 0;
    if (_rootNode != null) {
      totalNodes = 1;
      if (_rootNode!.status == 'final') finalNodes++;
      for (final list in _childCache.values) {
        totalNodes += list.length;
        for (final n in list) {
          if (n.status == 'final') finalNodes++;
        }
      }
    }
    final progress = totalNodes > 0 ? (finalNodes / totalNodes * 100).toStringAsFixed(0) : '0';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
      ),
      child: Row(children: [
        Icon(Icons.account_tree_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('节点: $totalNodes', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        Text('已定稿: $finalNodes', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        Text('进度: $progress%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
      ]),
    );
  }

  // ===== Reusable Layout Helpers =====

  Widget _buildResizablePanel({
    required double width, required double minWidth, required double maxWidth,
    required ValueChanged<double> onResize, required Widget child,
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
                onResize(width + details.delta.dx);
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
    required bool collapsed, required VoidCallback onToggle, required bool isLeft,
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
}

// ===== Data Classes =====

class _FlatNode {
  final OutlineNode node;
  final int depth;
  final bool hasChildren;
  _FlatNode({required this.node, required this.depth, required this.hasChildren});
}

class _AddNodeData {
  final String title;
  final String type;
  final String content;
  _AddNodeData({required this.title, required this.type, required this.content});
}

// ===== Add Node Dialog =====

class _AddNodeDialog extends StatefulWidget {
  final String parentTitle;
  final List<String> validTypes;
  final String defaultType;
  const _AddNodeDialog({required this.parentTitle, required this.validTypes, required this.defaultType});

  @override
  State<_AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<_AddNodeDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    _selectedType = widget.defaultType;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'volume': return '卷';
      case 'chapter': return '章';
      case 'section': return '节';
      case 'beat': return '剧情点';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加大纲节点'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('父节点: ${widget.parentTitle}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: '节点类型', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: widget.validTypes.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedType = v); },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '节点标题', hintText: '如：第一卷 少年崛起', isDense: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(labelText: '详细内容（可选）', isDense: true, alignLabelWithHint: true),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, _AddNodeData(
              title: _titleCtrl.text.trim(),
              type: _selectedType,
              content: _contentCtrl.text.trim(),
            ));
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}

// ===== Context Menu =====

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
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx, details.globalPosition.dy,
            details.globalPosition.dx + 1, details.globalPosition.dy + 1,
          ),
          items: items.map((item) => PopupMenuItem(
            onTap: item.onTap,
            child: Row(children: [
              Icon(item.icon, size: 16, color: item.isDestructive ? Colors.red : null),
              const SizedBox(width: 8),
              Text(item.label, style: item.isDestructive ? const TextStyle(color: Colors.red) : null),
            ]),
          )).toList(),
        );
      },
      child: child,
    );
  }
}