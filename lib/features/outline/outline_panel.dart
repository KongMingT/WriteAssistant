import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/utils/id_generator.dart';
import '../workspace/models/selection_state.dart';

class OutlinePanel extends ConsumerStatefulWidget {
  const OutlinePanel({super.key});

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  List<OutlineNode> _nodes = [];
  bool _isLoading = false;
  String? _currentChapterId;

  @override
  Widget build(BuildContext context) {
    final chapterId = ref.watch(selectedChapterProvider);
    if (chapterId != _currentChapterId) {
      _currentChapterId = chapterId;
      if (chapterId != null) _loadNodes(chapterId);
    }

    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Row(
            children: [
              Icon(Icons.list_alt_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('章纲', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
              if (_currentChapterId != null) ...[
                const Spacer(),
                SizedBox(
                  height: 24,
                  child: TextButton.icon(
                    onPressed: _addNode,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('添加', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_nodes.isEmpty && _currentChapterId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('暂无章纲，点击「添加」创建或使用 AI 生成', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withAlpha(120))),
          )
        else
          _buildNodeList(theme),
      ],
    );
  }

  Widget _buildNodeList(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        itemCount: _nodes.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 24),
        itemBuilder: (_, i) => _buildNodeItem(_nodes[i], theme),
      ),
    );
  }

  Widget _buildNodeItem(OutlineNode node, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withAlpha(120)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _editNode(node),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (node.title.isNotEmpty)
                    Text(node.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  if (node.content != null && node.content!.isNotEmpty)
                    Text(node.content!, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _deleteNode(node),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNodes(String chapterId) async {
    setState(() => _isLoading = true);
    final dao = ref.read(outlineDaoProvider);
    final nodes = await dao.getOutlineNodesByChapter(chapterId);
    if (mounted) setState(() { _nodes = nodes; _isLoading = false; });
  }

  Future<void> _addNode() async {
    if (_currentChapterId == null) return;
    final result = await showDialog<_OutlineNodeData>(
      context: context,
      builder: (_) => _OutlineNodeDialog(),
    );
    if (result != null && mounted) {
      final dao = ref.read(outlineDaoProvider);
      await dao.insertOutlineNode(OutlineNodesCompanion(
        id: Value(generateId()),
        chapterId: Value(_currentChapterId!),
        title: Value(result.title),
        content: Value(result.content.isEmpty ? null : result.content),
        sortOrder: Value(_nodes.length),
        type: const Value('outline'),
      ));
      _loadNodes(_currentChapterId!);
    }
  }

  Future<void> _editNode(OutlineNode node) async {
    final result = await showDialog<_OutlineNodeData>(
      context: context,
      builder: (_) => _OutlineNodeDialog(node: node),
    );
    if (result != null && mounted) {
      final dao = ref.read(outlineDaoProvider);
      await dao.updateOutlineNode(node.copyWith(
        title: result.title,
        content: Value(result.content.isEmpty ? null : result.content),
      ));
      _loadNodes(_currentChapterId!);
    }
  }

  Future<void> _deleteNode(OutlineNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除大纲节点'),
        content: Text('确定删除「${node.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final dao = ref.read(outlineDaoProvider);
      await dao.deleteOutlineNode(node.id);
      _loadNodes(_currentChapterId!);
    }
  }
}

class _OutlineNodeDialog extends StatefulWidget {
  final OutlineNode? node;
  const _OutlineNodeDialog({this.node});

  @override
  State<_OutlineNodeDialog> createState() => _OutlineNodeDialogState();
}

class _OutlineNodeDialogState extends State<_OutlineNodeDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.node?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.node?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.node == null ? '添加大纲节点' : '编辑大纲节点'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '节点标题', hintText: '如：主角初次登场', isDense: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(labelText: '详细内容（可选）', hintText: '该节点的具体剧情安排...', isDense: true, alignLabelWithHint: true),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, _OutlineNodeData(
          title: _titleCtrl.text,
          content: _contentCtrl.text,
        )), child: const Text('保存')),
      ],
    );
  }
}

class _OutlineNodeData {
  final String title;
  final String content;
  const _OutlineNodeData({required this.title, required this.content});
}
