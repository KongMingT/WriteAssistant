import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/books.dart';
import 'tables/chapters.dart';
import 'tables/character_relations.dart';
import 'tables/characters.dart';
import 'tables/outline_nodes.dart';
import 'tables/plot_lines.dart';
import 'tables/plot_nodes.dart';
import 'tables/volumes.dart';
import 'tables/writing_sessions.dart';

part 'database.g.dart';

// ===== 数据库定义 =====

@DriftDatabase(
  tables: [
    Books,
    Volumes,
    Chapters,
    OutlineNodes,
    Characters,
    CharacterRelations,
    PlotLines,
    PlotNodes,
    WritingSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(books, books.author);
          await m.addColumn(books, books.status);
          await m.addColumn(books, books.genre);
          await m.addColumn(volumes, volumes.updatedAt);
          await m.addColumn(characterRelations, characterRelations.createdAt);
          await m.addColumn(outlineNodes, outlineNodes.createdAt);
          await m.addColumn(outlineNodes, outlineNodes.updatedAt);
          await m.addColumn(plotLines, plotLines.sortOrder);
          await m.addColumn(plotLines, plotLines.createdAt);
          await m.addColumn(plotNodes, plotNodes.createdAt);
          await m.addColumn(plotNodes, plotNodes.updatedAt);
          await m.addColumn(writingSessions, writingSessions.chapterId);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'writer_assistant.db');
    return NativeDatabase(File(dbPath));
  });
}
