import 'package:drift/native.dart';
import 'package:writer_assistant/core/database/database.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());
