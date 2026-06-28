import 'package:drift/drift.dart';

import '../database.dart';

class VolumeDao extends DatabaseAccessor<AppDatabase> {
  VolumeDao(super.db);

  /// 获取某本书的所有卷（按排序）
  Future<List<Volume>> getVolumesByBook(String bookId) async {
    return (select(db.volumes)
          ..where((v) => v.bookId.equals(bookId))
          ..orderBy([(v) => OrderingTerm(expression: v.sortOrder)]))
        .get();
  }

  /// 按 ID 获取卷
  Future<Volume?> getVolumeById(String id) async {
    return (select(db.volumes)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  /// 创建卷
  Future<void> insertVolume(VolumesCompanion volume) async {
    await into(db.volumes).insert(volume);
  }

  /// 更新卷
  Future<void> updateVolume(Volume volume) async {
    await update(db.volumes).replace(volume);
  }

  /// 删除卷
  Future<void> deleteVolume(String id) async {
    await (delete(db.volumes)..where((v) => v.id.equals(id))).go();
  }
}
