import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/providers.dart';
import '../models/selection_state.dart';

class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({super.key});

  @override
  ConsumerState<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<SearchDialog> {
  final _queryCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();
  final _results = <_SearchMatch>[];
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _replaceCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results.clear(); _searching = false; });
      return;
    }

    setState(() => _searching = true);
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null) { setState(() => _searching = false); return; }

    final q = query.trim().toLowerCase();
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(bookId);
    final matches = <_SearchMatch>[];
    for (final vol in volumes) {
      final chapters = await chapterDao.getChaptersByVolume(vol.id);
      for (final ch in chapters) {
        final titleLower = ch.title.toLowerCase();
        if (titleLower.contains(q)) {
          matches.add(_SearchMatch(
            chapterId: ch.id,
            chapterTitle: ch.title,
            matchText: ch.title,
            matchIndex: 0,
            isTitle: true,
          ));
        }
        final content = ch.content;
        int start = 0;
        while (true) {
          final idx = content.toLowerCase().indexOf(q, start);
          if (idx < 0) break;
          final ctxStart = (idx - 20).clamp(0, content.length);
          final ctxEnd = (idx + q.length + 20).clamp(0, content.length);
          matches.add(_SearchMatch(
            chapterId: ch.id,
            chapterTitle: ch.title,
            matchText: content.substring(idx, idx + q.length),
            matchIndex: idx,
            context: ctxStart > 0 ? '...${content.substring(ctxStart, ctxEnd)}...' : '${content.substring(ctxStart, ctxEnd)}...',
            isTitle: false,
          ));
          start = idx + q.length;
        }
      }
    }

    if (mounted) setState(() { _results..clear()..addAll(matches); _searching = false; });
  }

  void _navigate(String chapterId) {
    ref.read(selectedChapterProvider.notifier).state = chapterId;
    Navigator.pop(context);
  }

  Future<void> _replaceOne(_SearchMatch match) async {
    final chapterDao = ref.read(chapterDaoProvider);
    final ch = await chapterDao.getChapterById(match.chapterId);
    if (ch == null) return;
    final newContent = ch.content.replaceFirst(
      ch.content.substring(match.matchIndex, match.matchIndex + match.matchText.length),
      _replaceCtrl.text,
      match.matchIndex,
    );
    await chapterDao.updateChapterContent(match.chapterId, newContent);
    ref.read(treeRefreshProvider.notifier).state++;
    await _search(_queryCtrl.text);
  }

  Future<void> _replaceAll() async {
    final bookId = ref.read(selectedBookProvider);
    if (bookId == null) return;
    final q = _queryCtrl.text.trim();
    final rep = _replaceCtrl.text;
    if (q.isEmpty) return;

    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    final volumes = await volumeDao.getVolumesByBook(bookId);
    int replaced = 0;
    for (final vol in volumes) {
      final chapters = await chapterDao.getChaptersByVolume(vol.id);
      for (final ch in chapters) {
        final newContent = ch.content.replaceAll(q, rep);
        if (newContent != ch.content) {
          await chapterDao.updateChapterContent(ch.id, newContent);
          replaced++;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已替换 $replaced 个章节'), duration: const Duration(seconds: 2)),
      );
      await _search(_queryCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18),
                const SizedBox(width: 8),
                const Text('搜索与替换', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text('Ctrl+F', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Search row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索章节内容...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searching
                    ? const SizedBox(width: 18, height: 18, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                    : _queryCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () { _queryCtrl.clear(); _results.clear(); setState(() {}); },
                          )
                        : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
              },
            ),
          ),
          // Replace row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceCtrl,
                    decoration: InputDecoration(
                      hintText: '替换为...',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _results.isEmpty ? null : _replaceAll,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('全部替换', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Results header
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('共 ${_results.length} 处匹配', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          // Results list
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _queryCtrl.text.isEmpty ? '输入关键词搜索所有章节' : '无匹配结果',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final match = _results[index];
                      return _buildResultItem(theme, match, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(ThemeData theme, _SearchMatch match, int index) {
    return InkWell(
      onTap: () => _navigate(match.chapterId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text('${index + 1}.', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.chapterTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                  const SizedBox(height: 2),
                  if (!match.isTitle && match.context != null)
                    Text(match.context!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_replaceCtrl.text.isNotEmpty)
              SizedBox(
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.find_replace, size: 16),
                  tooltip: '替换此项',
                  onPressed: () => _replaceOne(match),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchMatch {
  final String chapterId;
  final String chapterTitle;
  final String matchText;
  final int matchIndex;
  final bool isTitle;
  final String? context;

  _SearchMatch({
    required this.chapterId,
    required this.chapterTitle,
    required this.matchText,
    required this.matchIndex,
    required this.isTitle,
    this.context,
  });
}
