import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _themeKey = 'app_theme_mode';
const _fontSizeKey = 'editor_font_size';
const _fontFamilyKey = 'editor_font_family';

/// 主题模式
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) { _load(); }
  Future<void> _load() async {
    final value = await _storage.read(key: _themeKey);
    if (value != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == value, orElse: () => ThemeMode.system);
    }
  }
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _themeKey, value: mode.name);
  }
}

/// 编辑器字号
final editorFontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) => FontSizeNotifier());

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier() : super(16.0) { _load(); }
  Future<void> _load() async {
    final value = await _storage.read(key: _fontSizeKey);
    if (value != null) state = double.tryParse(value) ?? 16.0;
  }
  Future<void> setSize(double size) async {
    state = size;
    await _storage.write(key: _fontSizeKey, value: size.toStringAsFixed(1));
  }
}

/// 编辑器字体族
final editorFontFamilyProvider = StateNotifierProvider<FontFamilyNotifier, String>((ref) => FontFamilyNotifier());

class FontFamilyNotifier extends StateNotifier<String> {
  FontFamilyNotifier() : super('SimSun') { _load(); }
  Future<void> _load() async {
    final value = await _storage.read(key: _fontFamilyKey);
    if (value != null) state = value;
  }
  Future<void> setFamily(String family) async {
    state = family;
    await _storage.write(key: _fontFamilyKey, value: family);
  }
}
