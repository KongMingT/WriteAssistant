import 'package:flutter_test/flutter_test.dart';

import 'package:writer_assistant/core/services/txt_import_service.dart';

void main() {
  group('TxtImportService.splitChapters', () {
    final service = TxtImportService();

    test('识别标准"第X章"标题并分离正文', () {
      const text = '第一章 初入宗门\n这是第一章的正文。\n\n第二章 拜师\n这是第二章的正文。';
      final chapters = service.splitChapters(text);

      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章 初入宗门');
      expect(chapters[0].content, '这是第一章的正文。');
      expect(chapters[1].title, '第二章 拜师');
      expect(chapters[1].content, '这是第二章的正文。');
    });

    test('识别"序章/尾声/楔子"等特殊章节', () {
      const text = '序章\n序章正文。\n\n第一章 开局\n正文。\n\n尾声\n尾声正文。';
      final chapters = service.splitChapters(text);

      expect(chapters.length, 3);
      expect(chapters[0].title, '序章');
      expect(chapters[1].title, '第一章 开局');
      expect(chapters[2].title, '尾声');
    });

    test('识别英文 Chapter N / Volume N', () {
      const text = 'Chapter 1: The Beginning\nThe first chapter.';
      final chapters = service.splitChapters(text);

      expect(chapters.length, 1);
      expect(chapters[0].title, 'Chapter 1 The Beginning');
      expect(chapters[0].content, 'The first chapter.');
    });

    test('中文数字与阿拉伯数字章节', () {
      const text = '第一百二十三章 重逢\n正文A。\n\n第456章 再战\n正文B。';
      final chapters = service.splitChapters(text);

      expect(chapters.length, 2);
      expect(chapters[0].title, '第一百二十三章 重逢');
      expect(chapters[1].title, '第456章 再战');
    });

    test('卷级标题同样切分', () {
      const text = '第一卷 风起\n卷首正文。\n\n第一章 开端\n第一章正文。';
      final chapters = service.splitChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, '第一卷 风起');
      expect(chapters[1].title, '第一章 开端');
    });

    test('标题行不残留在正文中，正文不为空', () {
      const text = '第一章 测试\n正文第一句。';
      final chapters = service.splitChapters(text);
      expect(chapters[0].content, contains('正文第一句'));
      expect(chapters[0].content, isNot(contains('第一章')));
    });

    test('无章节标记时整体作为一个章节', () {
      const text = '整段文本。\n没有章节标题。';
      final chapters = service.splitChapters(text);
      expect(chapters.length, 1);
      expect(chapters[0].title, isEmpty);
      expect(chapters[0].content, contains('整段文本'));
    });

    test('章标题与正文同一行也能正确拆分', () {
      const text = '第一章 标题与正文同行\n这里才是正文。';
      final chapters = service.splitChapters(text);
      expect(chapters.length, 1);
      expect(chapters[0].title, '第一章 标题与正文同行');
    });
  });
}