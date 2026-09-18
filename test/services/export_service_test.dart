import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:writer_assistant/core/services/txt_export_service.dart';

void main() {
  final tempDir = Directory.systemTemp.createTempSync('export_test');

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('TxtExportService', () {
    const title = '第一章 测试';
    const content = '第一行内容。\n第二行内容。';
    const bookTitle = '测试之书';
    final chapters = <ExportChapter>[
      (title: '第一章 测试', content: '第一章正文。'),
      (title: '第二章 测试', content: '第二章正文。'),
    ];

    test('TXT 章节导出', () async {
      final service = TxtExportService();
      await service.exportChapter(directory: tempDir.path, title: title, content: content);
      final file = File('${tempDir.path}/$title.txt');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), content);
    });

    test('TXT 整书导出包含书名与章节标题', () async {
      final service = TxtExportService();
      await service.exportBook(directory: tempDir.path, bookTitle: bookTitle, chapters: chapters);
      final txt = File('${tempDir.path}/$bookTitle.txt').readAsStringSync();
      expect(txt.contains(bookTitle), isTrue);
      expect(txt.contains('第一章 测试'), isTrue);
      expect(txt.contains('第二章正文。'), isTrue);
    });

    test('Markdown 章节导出', () async {
      final service = TxtExportService();
      await service.exportChapter(
        directory: tempDir.path,
        title: title,
        content: content,
        format: ExportFormat.markdown,
      );
      final txt = File('${tempDir.path}/$title.md').readAsStringSync();
      expect(txt, '# $title\n\n$content\n');
    });

    test('Markdown 整书导出', () async {
      final service = TxtExportService();
      await service.exportBook(
        directory: tempDir.path,
        bookTitle: bookTitle,
        chapters: chapters,
        format: ExportFormat.markdown,
      );
      final txt = File('${tempDir.path}/$bookTitle.md').readAsStringSync();
      expect(txt.contains('# $bookTitle'), isTrue);
      expect(txt.contains('## 第一章 测试'), isTrue);
    });

    test('EPUB 导出生成合法 zip 且含 mimetype', () async {
      final service = TxtExportService();
      await service.exportBook(
        directory: tempDir.path,
        bookTitle: bookTitle,
        chapters: chapters,
        format: ExportFormat.epub,
      );
      final bytes = File('${tempDir.path}/$bookTitle.epub').readAsBytesSync();
      expect(bytes.length, greaterThan(200));

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names, contains('mimetype'));
      expect(names, contains('META-INF/container.xml'));
      expect(names, contains('OEBPS/content.opf'));
      expect(names, contains('OEBPS/toc.ncx'));
      expect(names, contains('OEBPS/chapter1.xhtml'));

      final mimetypeFile = archive.files.firstWhere((f) => f.name == 'mimetype');
      expect(mimetypeFile.isCompressed, isFalse);
      expect(utf8.decode(mimetypeFile.content as List<int>), 'application/epub+zip');

      final opf = utf8.decode(
          archive.files.firstWhere((f) => f.name == 'OEBPS/content.opf').content as List<int>);
      expect(opf, contains('dc:title'));
      expect(opf, contains('chapter1.xhtml'));
    });
  });
}