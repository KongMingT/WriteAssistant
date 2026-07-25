import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/services/txt_import_service.dart';
import '../../core/utils/id_generator.dart';
import '../workspace/models/selection_state.dart';
import '../workspace/workspace_screen.dart';

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
    ));
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
        title: const Text('WriterAssistant'),
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

  Widget _buildBookGrid(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的书籍', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${_books.length} 本书', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBook(book.id),
        onLongPress: () => _deleteBook(book),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book, color: theme.colorScheme.primary, size: 20),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'delete') _deleteBook(book);
                      if (v == 'open') _openBook(book.id);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'open', child: Text('打开')),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${book.wordCount} 字', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _createBook,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 36, color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
              const SizedBox(height: 8),
              Text('新建书籍', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
