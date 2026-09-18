import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const dailyGoalKey = 'daily_goal';

/// 每日写作目标（字），0 表示未设置
final dailyGoalProvider = StateNotifierProvider<DailyGoalNotifier, int>((ref) {
  return DailyGoalNotifier();
});

class DailyGoalNotifier extends StateNotifier<int> {
  DailyGoalNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: dailyGoalKey);
    if (value != null && mounted) {
      state = int.tryParse(value) ?? 0;
    }
  }

  Future<void> setGoal(int goal) async {
    state = goal;
    await _storage.write(key: dailyGoalKey, value: '$goal');
  }
}