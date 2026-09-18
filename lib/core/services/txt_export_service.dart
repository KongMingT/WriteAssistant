import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

export 'package:file_picker/file_picker.dart' show FilePicker;

/// 导出的章节数据
typedef ExportChapter = ({String title, String content});

/// 支持的导出格式
enum ExportFormat {
  txt('TXT', 'txt'),
  markdown('Markdown', 'md'),
  epub('EPUB', 'epub'),
  ;

  final String displayName;
  final String extension;
  const ExportFormat(this.displayName, this.extension);
}

/// 书籍导出服务：支持 TXT / Markdown / EPUB
class TxtExportService {
  /// 选择导出目录
  Future<String?> pickExportDirectory() async {
    return FilePicker.getDirectoryPath();
  }

  /// 单章节导出
  Future<void> exportChapter({
    required String directory,
    required String title,
    required String content,
    ExportFormat format = ExportFormat.txt,
  }) async {
    final safeName = _safeName(title);
    final baseName = '$safeName.${format.extension}';
    final file = File(p.join(directory, baseName));
    switch (format) {
      case ExportFormat.txt:
        await file.writeAsString(content, encoding: utf8);
      case ExportFormat.markdown:
        await file.writeAsString(_markdownChapter(title, content), encoding: utf8);
      case ExportFormat.epub:
        await file.writeAsBytes(_epubBytes(bookTitle: safeName, chapters: [(title: title, content: content)]));
    }
  }

  /// 整书导出
  Future<void> exportBook({
    required String directory,
    required String bookTitle,
    required List<ExportChapter> chapters,
    ExportFormat format = ExportFormat.txt,
  }) async {
    final safeName = _safeName(bookTitle);
    final file = File(p.join(directory, '$safeName.${format.extension}'));
    switch (format) {
      case ExportFormat.txt:
        await file.writeAsString(_txtBook(bookTitle, chapters), encoding: utf8);
      case ExportFormat.markdown:
        await file.writeAsString(_markdownBook(bookTitle, chapters), encoding: utf8);
      case ExportFormat.epub:
        await file.writeAsBytes(_epubBytes(bookTitle: bookTitle, chapters: chapters));
    }
  }

  // ===== 格式生成 =====

  String _txtBook(String bookTitle, List<ExportChapter> chapters) {
    final buffer = StringBuffer()..writeln(bookTitle)..writeln()..writeln();
    for (final ch in chapters) {
      buffer
        ..writeln(ch.title)
        ..writeln()
        ..writeln(ch.content)
        ..writeln()
        ..writeln();
    }
    return buffer.toString();
  }

  String _markdownChapter(String title, String content) {
    return '# $title\n\n$content\n';
  }

  String _markdownBook(String bookTitle, List<ExportChapter> chapters) {
    final buffer = StringBuffer()..writeln('# $bookTitle')..writeln();
    for (final ch in chapters) {
      buffer
        ..writeln()
        ..writeln('## ${ch.title}')
        ..writeln()
        ..writeln(ch.content);
    }
    return buffer.toString();
  }

  // ===== EPUB 生成 =====

  String _safeName(String name) => name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

  /// 生成 EPUB 文件字节
  List<int> _epubBytes({
    required String bookTitle,
    required List<ExportChapter> chapters,
  }) {
    final now = DateTime.now();
    final bookId = 'urn:uuid:${now.microsecondsSinceEpoch.toRadixString(16)}';
    final idReplacer = RegExp(r'[^\w-]', multiLine: true);

    final buffer = Archive();

    void addFile(String path, Uint8List bytes, {bool store = false}) {
      if (store) {
        buffer.addFile(ArchiveFile.noCompress(path, bytes.length, bytes));
      } else {
        buffer.addFile(ArchiveFile(path, bytes.length, bytes));
      }
    }

    Uint8List utf8List(String s) => Uint8List.fromList(utf8.encode(s));

    // mimetype 必须无压缩、排最前
    addFile('mimetype', utf8List('application/epub+zip'), store: true);
    addFile('META-INF/container.xml', utf8List(_containerXml));
    addFile('OEBPS/content.opf', utf8List(_contentOpf(bookTitle, bookId, chapters, idReplacer)));
    addFile('OEBPS/toc.ncx', utf8List(_tocNcx(bookTitle, bookId, chapters, idReplacer)));
    addFile('OEBPS/style.css', utf8List(_styleCss));

    for (var i = 0; i < chapters.length; i++) {
      addFile('OEBPS/chapter${i + 1}.xhtml', utf8List(_chapterXhtml(chapters[i].title, chapters[i].content)));
    }

    return ZipEncoder().encode(buffer) ?? const [];
  }

  String get _containerXml => '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

  String _contentOpf(String bookTitle, String bookId, List<ExportChapter> chapters, RegExp idReplacer) {
    final manifest = StringBuffer();
    final spine = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final id = 'chapter${i + 1}';
      manifest.writeln('    <item id="$id" href="chapter${i + 1}.xhtml" media-type="application/xhtml+xml"/>');
      spine.writeln('    <itemref idref="$id"/>');
    }
    final cleanTitle = bookTitle.replaceAll(idReplacer, '_');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="BookId">$bookId</dc:identifier>
    <dc:title>$cleanTitle</dc:title>
    <dc:language>zh-CN</dc:language>
    <dc:creator>WriterAssistant</dc:creator>
    <meta name="generator" content="WriterAssistant"/>
  </metadata>
  <manifest>
    <item id="style" href="style.css" media-type="text/css"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
$manifest  </manifest>
  <spine toc="ncx">
$spine  </spine>
</package>
''';
  }

  String _tocNcx(String bookTitle, String bookId, List<ExportChapter> chapters, RegExp idReplacer) {
    final navPoints = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final cleanTitle = chapters[i].title.replaceAll(idReplacer, '_');
      navPoints.writeln('    <navPoint id="np${i + 1}" playOrder="${i + 1}">'
          '<navLabel><text>$cleanTitle</text></navLabel>'
          '<content src="chapter${i + 1}.xhtml"/></navPoint>');
    }
    final cleanTitle = bookTitle.replaceAll(idReplacer, '_');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="$bookId"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>$cleanTitle</text></docTitle>
  <navMap>
$navPoints  </navMap>
</ncx>
''';
  }

  String get _styleCss => '''
body { font-family: "Noto Serif CJK SC", "Songti SC", serif; }
h1 { text-align: center; }
h2 { text-align: center; }
p { text-indent: 2em; line-height: 1.6; }
''';

  String _chapterXhtml(String title, String content) {
    final htmlTitle = _escapeXml(title);
    final paragraphs = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '<p>${_escapeXml(line)}</p>');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>$htmlTitle</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
  <h2>$htmlTitle</h2>
${paragraphs.join('\n')}
</body>
</html>
''';
  }

  String _escapeXml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}