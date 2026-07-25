import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'shared/themes/theme_provider.dart';

const _storage = FlutterSecureStorage();
const _themeKey = 'app_theme_mode';

Future<ThemeMode> _loadThemeMode() async {
  try {
    final value = await _storage.read(key: _themeKey);
    if (value != null) {
      return ThemeMode.values.firstWhere((m) => m.name == value);
    }
  } catch (_) {}
  return ThemeMode.system;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialTheme = await _loadThemeMode();
  runApp(ProviderScope(
    overrides: [
      initialThemeModeProvider.overrideWithValue(initialTheme),
    ],
    child: const WriterAssistantApp(),
  ));
}
