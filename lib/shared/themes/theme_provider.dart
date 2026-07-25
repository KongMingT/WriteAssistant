import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _themeKey = 'app_theme_mode';
const _fontSizeKey = 'editor_font_size';
const _fontFamilyKey = 'editor_font_family';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final initial = ref.watch(initialThemeModeProvider);
  return ThemeModeNotifier(initial);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.state);

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _themeKey, value: mode.name);
  }
}

final editorFontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) => FontSizeNotifier());

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier() : super(16.0) { _load(); }
  Future<void> _load() async {
    final value = await _storage.read(key: _fontSizeKey);
    if (value != null && mounted) state = double.tryParse(value) ?? 16.0;
  }
  Future<void> setSize(double size) async {
    state = size;
    await _storage.write(key: _fontSizeKey, value: size.toStringAsFixed(1));
  }
}

final editorFontFamilyProvider = StateNotifierProvider<FontFamilyNotifier, String>((ref) => FontFamilyNotifier());

class FontFamilyNotifier extends StateNotifier<String> {
  FontFamilyNotifier() : super('SimSun') { _load(); }
  Future<void> _load() async {
    final value = await _storage.read(key: _fontFamilyKey);
    if (value != null && mounted) state = value;
  }
  Future<void> setFamily(String family) async {
    state = family;
    await _storage.write(key: _fontFamilyKey, value: family);
  }
}
