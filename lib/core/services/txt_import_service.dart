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

  /// 将 TXT 内容按章节拆分（按"第X章"或空行分割）
  List<String> splitChapters(String content) {
    // 按常见的章节标题分割
    final chapterPattern = RegExp(r'(第[一二三四五六七八九十百千万０-９0-9]+[章回节部])');
    final parts = content.split(chapterPattern);
    if (parts.length <= 1) {
      // 没有找到章节标记，整体作为一个章节
      return [content.trim()];
    }
    // 合并标题和内容
    final chapters = <String>[];
    for (int i = 0; i < parts.length - 1; i += 2) {
      final title = parts[i].trim();
      final body = (i + 1 < parts.length ? parts[i + 1] : '').trim();
      if (title.isNotEmpty) {
        chapters.add('$title\n$body');
      } else if (body.isNotEmpty) {
        chapters.add(body);
      }
    }
    if (chapters.isEmpty) chapters.add(content.trim());
    return chapters;
  }
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
