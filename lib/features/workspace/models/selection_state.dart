import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前选中的章节 ID
final selectedChapterProvider = StateProvider<String?>((ref) => null);

/// 当前选中的书籍 ID
final selectedBookProvider = StateProvider<String?>((ref) => null);

/// 触发目录树刷新
final treeRefreshProvider = StateProvider<int>((ref) => 0);

/// 写作状态（字数、速度）
class WritingState {
  final int wordCount;
  final int writingSpeed;
  final String sessionDuration;

  const WritingState({
    this.wordCount = 0,
    this.writingSpeed = 0,
    this.sessionDuration = '',
  });
}

final writingStateProvider = StateProvider<WritingState>((ref) => const WritingState());

/// 强制保存信号（触发即时保存，绕过防抖）
final forceSaveProvider = StateProvider<int>((ref) => 0);

/// 新建章节信号
final newChapterRequestProvider = StateProvider<int>((ref) => 0);

/// 新建书籍信号
final newBookRequestProvider = StateProvider<int>((ref) => 0);

