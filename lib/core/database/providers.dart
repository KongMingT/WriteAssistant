import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daos/book_dao.dart';
import 'daos/chapter_dao.dart';
import 'daos/character_dao.dart';
import 'daos/outline_dao.dart';
import 'daos/plot_dao.dart';
import 'daos/session_dao.dart';
import 'daos/volume_dao.dart';
import 'database.dart';

/// 数据库单例 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// DAO Providers
final bookDaoProvider = Provider<BookDao>((ref) {
  return BookDao(ref.watch(databaseProvider));
});

final volumeDaoProvider = Provider<VolumeDao>((ref) {
  return VolumeDao(ref.watch(databaseProvider));
});

final chapterDaoProvider = Provider<ChapterDao>((ref) {
  return ChapterDao(ref.watch(databaseProvider));
});

final characterDaoProvider = Provider<CharacterDao>((ref) {
  return CharacterDao(ref.watch(databaseProvider));
});

final plotDaoProvider = Provider<PlotDao>((ref) {
  return PlotDao(ref.watch(databaseProvider));
});

final outlineDaoProvider = Provider<OutlineDao>((ref) {
  return OutlineDao(ref.watch(databaseProvider));
});

final sessionDaoProvider = Provider<SessionDao>((ref) {
  return SessionDao(ref.watch(databaseProvider));
});
