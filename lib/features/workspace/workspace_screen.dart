import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../book_analysis/book_analysis_screen.dart';
import '../character/character_list_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/services/txt_import_service.dart';
import '../../core/utils/id_generator.dart';
import '../../shared/widgets/status_bar.dart';
import 'ai_panel/ai_panel.dart';
import 'editor/chapter_editor.dart';
import 'models/selection_state.dart';
import 'sidebar/chapter_tree.dart';

/// 三栏工作区主界面
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  double _sidebarWidth = 250;
  double _aiPanelWidth = 300;
  bool _sidebarCollapsed = false;
  bool _aiPanelCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: const ChapterTree(),
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
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('WriterAssistant'),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.file_open_outlined),
          tooltip: '导入 TXT',
          onPressed: () => _importTxt(),
        ),
        IconButton(
          icon: const Icon(Icons.people_outlined),
          tooltip: '人物管理',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterListScreen())),
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

    Future<void> _importTxt() async {
    final importService = TxtImportService();
    final result = await importService.pickAndReadTxt();
    if (result != null && mounted) {
      final now = DateTime.now();
      final bookId = generateId();
      final volId = generateId();
      final bookDao = ref.read(bookDaoProvider);
      final volumeDao = ref.read(volumeDaoProvider);
      final chapterDao = ref.read(chapterDaoProvider);
      await bookDao.insertBook(BooksCompanion(
        id: Value(bookId), title: Value(result.fileName),
        createdAt: Value(now), updatedAt: Value(now),
      ));
      await volumeDao.insertVolume(VolumesCompanion(
        id: Value(volId), bookId: Value(bookId), title: const Value('第一卷'),
        sortOrder: const Value(0), createdAt: Value(now),
      ));
      final chapters = importService.splitChapters(result.content);
      for (int i = 0; i < chapters.length; i++) {
        await chapterDao.insertChapter(ChaptersCompanion(
          id: Value(generateId()), volumeId: Value(volId),
          title: Value('第${i + 1}章'), content: Value(chapters[i]),
          wordCount: Value(chapters[i].length),
          sortOrder: Value(i), createdAt: Value(now), updatedAt: Value(now),
        ));
      }
      ref.read(treeRefreshProvider.notifier).state++;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入 ${chapters.length} 章到「${result.fileName}」')));
    }
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
