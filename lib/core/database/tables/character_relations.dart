import 'package:drift/drift.dart';

import 'books.dart';
import 'characters.dart';

class CharacterRelations extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get characterAId => text().references(Characters, #id)();
  TextColumn get characterBId => text().references(Characters, #id)();
  TextColumn get relationType => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
