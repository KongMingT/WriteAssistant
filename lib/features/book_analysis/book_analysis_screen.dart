import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_client.dart';
import '../../core/ai/models/ai_model_config.dart';
import '../../core/ai/prompts/prompts.dart';
import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/services/txt_import_service.dart';
import '../../core/utils/id_generator.dart';

/// 拆书分析页面
class BookAnalysisScreen extends ConsumerStatefulWidget {
  const BookAnalysisScreen({super.key});

  @override
  ConsumerState<BookAnalysisScreen> createState() => _BookAnalysisScreenState();
}

class _BookAnalysisScreenState extends ConsumerState<BookAnalysisScreen> {
  final _txtService = TxtImportService();
  String? _fileName;
  String? _analysisResult;
  bool _isAnalyzing = false;
  String? _importedContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('拆书分析'),
        centerTitle: false,
        actions: [
          if (_importedContent != null)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: '导入为书籍',
              onPressed: _importAsBook,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 导入区域
            _buildImportArea(theme),
            const SizedBox(height: 16),
            if (_fileName != null) ...[
              Text('已导入: $_fileName', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
            ],
            if (_importedContent != null && _analysisResult == null && !_isAnalyzing)
              FilledButton.icon(
                onPressed: _startAnalysis,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('开始 AI 分析'),
              ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('AI 正在分析中...'),
            ],
            if (_analysisResult != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('分析结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: '复制结果',
                    onPressed: () {
                      if (_analysisResult != null) {
                        Clipboard.setData(ClipboardData(text: _analysisResult!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分析结果已复制到剪贴板'), duration: Duration(seconds: 2)));
                      }
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _analysisResult!,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
            ],
            if (_analysisResult == null && !_isAnalyzing && _importedContent == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 64, color: theme.colorScheme.primary.withAlpha(60)),
                      const SizedBox(height: 16),
                      Text('选择一个 TXT 文件，AI 将自动分析人物关系、剧情节奏', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportArea(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _pickFile,
      icon: const Icon(Icons.file_open_outlined, size: 18),
      label: const Text('选择 TXT 文件'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await _txtService.pickAndReadTxt();
    if (result != null && mounted) {
      setState(() {
        _fileName = result.fileName;
        _importedContent = result.content;
        _analysisResult = null;
      });
    }
  }

  Future<void> _startAnalysis() async {
    if (_importedContent == null) return;
    setState(() => _isAnalyzing = true);
    try {
      final config = await ref.read(aiConfigProvider.future);
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先在设置中配置 API Key')));
        setState(() => _isAnalyzing = false);
        return;
      }
      final client = AiClient();
      final response = await client.chat(
        provider: config.provider,
        apiKey: config.apiKey!,
        messages: [
          const AiMessage(role: 'system', content: '你是一个专业的小说分析助手。请基于以下小说内容进行分析。'),
          AiMessage(role: 'user', content: AiPrompts.bookAnalysis(_importedContent!.substring(0, _importedContent!.length > 8000 ? 8000 : _importedContent!.length))),
        ],
      );
      if (mounted) setState(() { _analysisResult = response.content; _isAnalyzing = false; });
    } catch (e) {
      if (mounted) setState(() { _analysisResult = '分析失败: $e'; _isAnalyzing = false; });
    }
  }

  Future<void> _importAsBook() async {
    if (_importedContent == null) return;
    final now = DateTime.now();
    final bookId = generateId();
    final volId = generateId();
    final bookDao = ref.read(bookDaoProvider);
    final volumeDao = ref.read(volumeDaoProvider);
    final chapterDao = ref.read(chapterDaoProvider);
    await bookDao.insertBook(BooksCompanion(
      id: Value(bookId), title: Value(_fileName ?? '导入书籍'),
      createdAt: Value(now), updatedAt: Value(now),
    ));
    await volumeDao.insertVolume(VolumesCompanion(
      id: Value(volId), bookId: Value(bookId), title: const Value('第一卷'),
      sortOrder: const Value(0), createdAt: Value(now),
    ));
    final chapters = _txtService.splitChapters(_importedContent!);
    for (int i = 0; i < chapters.length; i++) {
      await chapterDao.insertChapter(ChaptersCompanion(
        id: Value(generateId()), volumeId: Value(volId),
        title: Value('第${i + 1}章'), content: Value(chapters[i]),
        wordCount: Value(chapters[i].length),
        sortOrder: Value(i), createdAt: Value(now), updatedAt: Value(now),
      ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入 ${chapters.length} 章到「${_fileName}」')));
    }
  }
}
