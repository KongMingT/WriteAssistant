import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// TXT 文件导入服务
class TxtImportService {
  /// 选择并读取 TXT 文件
  Future<TxtImportResult?> pickAndReadTxt() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final filePath = result.files.first.path;
    if (filePath == null) return null;
    return _readFile(filePath);
  }

  /// 读取 TXT 文件（自动检测编码）
  Future<TxtImportResult> _readFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final encoding = _detectEncoding(bytes);
    final content = encoding.decode(bytes);
    final fileName = filePath.split(Platform.pathSeparator).last.replaceAll('.txt', '');
    return TxtImportResult(
      fileName: fileName,
      content: content,
      encoding: encoding,
      filePath: filePath,
    );
  }

  /// 编码检测（BOM + 启发式）
  Encoding _detectEncoding(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8;
    }
    try {
      final asUtf8 = utf8.decode(bytes);
      if (!asUtf8.contains('\uFFFD')) return utf8;
    } catch (_) {}
    return Encoding.getByName('gbk') ?? utf8;
  }

  /// 将 TXT 内容按章节拆分（支持 第X章/卷/回/节/部、序章/尾声/楔子、Chapter N）
  ///
  /// 返回结构化章节：标题（提取到的原始标题，无则空串）与正文分离，
  /// 标题行不会残留在正文中。
  List<ImportedChapter> splitChapters(String content) {
    final lines = content.split('\n');
    final chapters = <ImportedChapter>[];
    var currentTitle = '';
    final currentBody = <String>[];

    void flush() {
      final body = _cleanBody(currentBody);
      if (currentTitle.isNotEmpty || body.isNotEmpty) {
        chapters.add(ImportedChapter(title: currentTitle, content: body));
      }
      currentBody.clear();
      currentTitle = '';
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        currentBody.add(rawLine);
        continue;
      }
      final header = _matchHeader(line);
      if (header != null) {
        flush();
        currentTitle = header;
        continue;
      }
      currentBody.add(rawLine);
    }
    flush();

    if (chapters.isEmpty) {
      return [ImportedChapter(title: '', content: content.trim())];
    }
    return chapters;
  }

  /// 尝试把一行识别为章节标题；返回标题串，非标题返回 null。
  ///
  /// 仅在"标题标记 + 可选分隔符 + 标题后缀/空"的形态下才判定为章标题，
  /// 形如"第一章正文。"的正文不受影响。
  String? _matchHeader(String line) {
    // 中文："第X章/卷/回/节/部" 与 序章/尾声等
    final zh = RegExp(
      r'^(第[0-9０-９零〇一二三四五六七八九十百千万两]+[章回节部卷]|序章|序言|前言|引子|楔子|尾声|终章|后记|结语|完本感言|番外)',
    ).firstMatch(line);

    // 英文：Chapter/Volume/Part/Prologue/Epilogue + 序号
    final en = RegExp(r'^([Cc]hapter|[Vv]olume|[Pp]art|[Pp]rologue|[Ee]pilogue)\s+([0-9０-９一二三四五六七八九十百千万]+)')
        .firstMatch(line);

    final match = zh ?? en;
    if (match == null) return null;

    final rest = line.substring(match.end);
    if (rest.isEmpty) return match.group(0)!.trim();
    // 必须有分隔符（空白/标点）才算标题后缀，否则视为正文
    if (!RegExp(r'^[:：、.，,;；\-—\s]').hasMatch(rest)) return null;
    final tail = rest.replaceFirst(RegExp(r'^[:：、.，,;；\-—\s]+'), '').trim();
    return tail.isEmpty ? match.group(0)!.trim() : '${match.group(0)!.trim()} $tail';
  }

  String _cleanBody(List<String> lines) {
    return lines.map((l) => l.trimRight()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

/// 导入的单个章节（标题与正文分离）
class ImportedChapter {
  final String title;
  final String content;

  const ImportedChapter({required this.title, required this.content});
}

class TxtImportResult {
  final String fileName;
  final String content;
  final Encoding encoding;
  final String filePath;

  const TxtImportResult({
    required this.fileName,
    required this.content,
    required this.encoding,
    required this.filePath,
  });
}
