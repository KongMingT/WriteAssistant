import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/services/txt_import_service.dart';
import '../../core/utils/id_generator.dart';
import '../workspace/models/selection_state.dart';
import '../workspace/workspace_screen.dart';
import '../../shared/widgets/app_logo.dart';

class BookSelectionScreen extends ConsumerStatefulWidget {
  const BookSelectionScreen({super.key});

  @override
  ConsumerState<BookSelectionScreen> createState() => _BookSelectionScreenState();
}

class _BookSelectionScreenState extends ConsumerState<BookSelectionScreen> {
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final bookDao = ref.read(bookDaoProvider);
    final books = await bookDao.getAllBooks();
    if (mounted) setState(() { _books = books; _isLoading = false; });
  }

  Future<void> _createBook() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建书籍'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '书名', hintText: '输入书籍名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (result == true && controller.text.isNotEmpty && mounted) {
      final now = DateTime.now();
      final bookId = generateId();
      final volId = generateId();
      final chapId = generateId();
      final bookDao = ref.read(bookDaoProvider);
      final volumeDao = ref.read(volumeDaoProvider);
      final chapterDao = ref.read(chapterDaoProvider);
      await bookDao.insertBook(BooksCompanion(
        id: Value(bookId), title: Value(controller.text),
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
      _openBook(bookId);
    }
    controller.dispose();
  }

  Future<void> _editBookName(Book book) async {
    final controller = TextEditingController(text: book.title);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑书名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '书名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (result == true && controller.text.isNotEmpty && mounted) {
      final bookDao = ref.read(bookDaoProvider);
      await bookDao.updateBook(book.copyWith(title: controller.text));
      _loadBooks();
    }
    controller.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入 ${chapters.length} 章到「${result.fileName}」')));
        _openBook(bookId);
      }
    }
  }

  void _openBook(String bookId) {
    ref.read(selectedBookProvider.notifier).state = bookId;
    ref.read(selectedChapterProvider.notifier).state = null;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkspaceScreen(bookId: bookId),
    )).then((_) => _loadBooks());
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定删除「${book.title}」吗？\n所有卷和章节也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final bookDao = ref.read(bookDaoProvider);
      await bookDao.deleteBook(book.id);
      _loadBooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 28, showText: true),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: '导入 TXT',
            onPressed: _importTxt,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建书籍',
            onPressed: _createBook,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _books.isEmpty
              ? _buildEmptyState(theme)
              : _buildBookGrid(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: theme.colorScheme.primary.withAlpha(60)),
          const SizedBox(height: 16),
          Text('还没有书籍', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 8),
          Text('新建一本书开始写作', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(120))),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _createBook,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建书籍'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _importTxt,
            icon: const Icon(Icons.file_open_outlined, size: 18),
            label: const Text('导入 TXT'),
          ),
        ],
      ),
    );
  }

  static const _coverColors = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    [Color(0xFF84CC16), Color(0xFFA3E635)],
  ];

  List<Color> _coverGradient(String id) {
    return _coverColors[id.hashCode.abs() % _coverColors.length];
  }

  String _formatTitle(String title) {
    if (title.length <= 5) return title;
    if (title.length <= 10) {
      return '${title.substring(0, 5)}\n${title.substring(5)}';
    }
    if (title.length <= 15) {
      return '${title.substring(0, 5)}\n${title.substring(5, 10)}\n${title.substring(10)}';
    }
    return '${title.substring(0, 5)}\n${title.substring(5, 10)}\n${title.substring(10, 15)}…';
  }

  Widget _buildBookGrid(ThemeData theme) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1200 ? 6 : (width > 900 ? 5 : 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('我的书籍', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${_books.length} 本', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.65,
              ),
              itemCount: _books.length + 1,
              itemBuilder: (_, i) {
                if (i == _books.length) return _buildAddCard(theme);
                return _buildBookCard(_books[i], theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Book book, ThemeData theme) {
    final gradient = _coverGradient(book.id);

    return Card(
      elevation: 2,
      shadowColor: gradient[0].withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openBook(book.id),
        onLongPress: () => _editBookName(book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面区域
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                child: Stack(
                  children: [
                    // 装饰圆
                    Positioned(
                      top: -20, right: -20,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10, left: -10,
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(10),
                        ),
                      ),
                    ),
                    // 书名居中显示
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _formatTitle(book.title),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 右上角菜单
                    Positioned(
                      top: 2, right: 2,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 14, color: Colors.white.withAlpha(160)),
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: EdgeInsets.zero,
                        onSelected: (v) {
                          if (v == 'edit') _editBookName(book);
                          if (v == 'delete') _deleteBook(book);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑书名')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部信息
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${book.wordCount} 字',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(ThemeData theme) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _createBook,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 28, color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
              const SizedBox(height: 6),
              Text('新建书籍', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

}
