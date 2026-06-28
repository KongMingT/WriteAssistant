import 'package:drift/drift.dart';

import '../database.dart';

class CharacterDao extends DatabaseAccessor<AppDatabase> {
  CharacterDao(super.db);

  /// 获取某本书的所有人物
  Future<List<Character>> getCharactersByBook(String bookId) async {
    return (select(db.characters)..where((c) => c.bookId.equals(bookId)))
        .get();
  }

  /// 按 ID 获取人物
  Future<Character?> getCharacterById(String id) async {
    return (select(db.characters)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// 创建人物
  Future<void> insertCharacter(CharactersCompanion character) async {
    await into(db.characters).insert(character);
  }

  /// 更新人物
  Future<void> updateCharacter(Character character) async {
    await update(db.characters).replace(character);
  }

  /// 删除人物
  Future<void> deleteCharacter(String id) async {
    await (delete(db.characters)..where((c) => c.id.equals(id))).go();
  }

  // ===== 人物关系 =====

  /// 获取某本书的所有人物关系
  Future<List<CharacterRelation>> getRelationsByBook(String bookId) async {
    return (select(db.characterRelations)
          ..where((r) => r.bookId.equals(bookId)))
        .get();
  }

  /// 创建人物关系
  Future<void> insertRelation(CharacterRelationsCompanion relation) async {
    await into(db.characterRelations).insert(relation);
  }

  /// 删除人物关系
  Future<void> deleteRelation(String id) async {
    await (delete(db.characterRelations)..where((r) => r.id.equals(id))).go();
  }
}
