import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class TxtExportService {
  Future<String?> pickExportDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    return path;
  }

  Future<void> exportChapter(String directory, String title, String content) async {
    final safeName = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final file = File(p.join(directory, '$safeName.txt'));
    await file.writeAsString(content, encoding: utf8);
  }

  Future<void> exportBook(String directory, String bookTitle, List<({String title, String content})> chapters) async {
    final safeName = bookTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final buffer = StringBuffer();
    for (final ch in chapters) {
      buffer.writeln(ch.title);
      buffer.writeln('');
      buffer.writeln(ch.content);
      buffer.writeln('');
      buffer.writeln('');
    }
    final file = File(p.join(directory, '$safeName.txt'));
    await file.writeAsString(buffer.toString(), encoding: utf8);
  }
}
