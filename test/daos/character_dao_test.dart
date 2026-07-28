import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:writer_assistant/core/database/database.dart';
import 'package:writer_assistant/core/database/daos/character_dao.dart';
import 'package:writer_assistant/core/utils/id_generator.dart';

import 'test_utils.dart';

const _bookId = 'char-test-book';

Future<void> _seedBook(AppDatabase db) async {
  await db.into(db.books).insert(BooksCompanion(
        id: Value(_bookId),
        title: Value('Test Book'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
}

void main() {
  late AppDatabase db;
  late CharacterDao dao;

  setUp(() async {
    db = createTestDb();
    await _seedBook(db);
    dao = CharacterDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CharacterDao', () {
    test('insert and get characters by book', () async {
      await dao.insertCharacter(CharactersCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        name: Value('Alice'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final chars = await dao.getCharactersByBook(_bookId);
      expect(chars.length, 1);
      expect(chars.first.name, 'Alice');
    });

    test('get character by id', () async {
      final id = generateId();
      await dao.insertCharacter(CharactersCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        name: Value('Bob'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final char = await dao.getCharacterById(id);
      expect(char, isNotNull);
      expect(char!.name, 'Bob');

      final notFound = await dao.getCharacterById('nonexistent');
      expect(notFound, isNull);
    });

    test('update character', () async {
      final id = generateId();
      await dao.insertCharacter(CharactersCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        name: Value('Charlie'),
        roleType: Value('protagonist'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      final char = await dao.getCharacterById(id);
      await dao.updateCharacter(char!.copyWith(
        name: 'Charlie Updated',
        roleType: 'antagonist',
      ));

      final updated = await dao.getCharacterById(id);
      expect(updated!.name, 'Charlie Updated');
      expect(updated.roleType, 'antagonist');
    });

    test('delete character', () async {
      final id = generateId();
      await dao.insertCharacter(CharactersCompanion(
        id: Value(id),
        bookId: Value(_bookId),
        name: Value('To Delete'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));

      await dao.deleteCharacter(id);
      final chars = await dao.getCharactersByBook(_bookId);
      expect(chars, isEmpty);
    });

    test('insert and get relations', () async {
      final charAId = generateId();
      final charBId = generateId();
      for (final id in [charAId, charBId]) {
        await dao.insertCharacter(CharactersCompanion(
          id: Value(id),
          bookId: Value(_bookId),
          name: Value('Char $id'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
      }

      await dao.insertRelation(CharacterRelationsCompanion(
        id: Value(generateId()),
        bookId: Value(_bookId),
        characterAId: Value(charAId),
        characterBId: Value(charBId),
        relationType: Value('friends'),
        createdAt: Value(DateTime.now()),
      ));

      final relations = await dao.getRelationsByBook(_bookId);
      expect(relations.length, 1);
      expect(relations.first.relationType, 'friends');
    });

    test('delete relation', () async {
      final charAId = generateId();
      final charBId = generateId();
      for (final id in [charAId, charBId]) {
        await dao.insertCharacter(CharactersCompanion(
          id: Value(id),
          bookId: Value(_bookId),
          name: Value('Char'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
      }

      final relId = generateId();
      await dao.insertRelation(CharacterRelationsCompanion(
        id: Value(relId),
        bookId: Value(_bookId),
        characterAId: Value(charAId),
        characterBId: Value(charBId),
        relationType: Value('rivals'),
        createdAt: Value(DateTime.now()),
      ));

      await dao.deleteRelation(relId);
      final relations = await dao.getRelationsByBook(_bookId);
      expect(relations, isEmpty);
    });
  });
}
