import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/providers.dart';
import '../../features/workspace/models/selection_state.dart';
import '../themes/theme_provider.dart';
import 'daily_goal_provider.dart';
import 'writing_stats_dialog.dart';

/// 底部状态栏 - 显示字数、码字速度、今日累计等
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(writingStateProvider);
    final todayCount = ref.watch(todayWordCountProvider).valueOrNull ?? 0;
    final dailyGoal = ref.watch(dailyGoalProvider);
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
      ),
      child: Row(
        children: [
          _StatusItem(icon: Icons.text_fields, label: '字数', value: '${state.wordCount}'),
          const SizedBox(width: 24),
          _StatusItem(icon: Icons.speed, label: '速度', value: '${state.writingSpeed} 字/时'),
          if (state.sessionDuration.isNotEmpty) ...[
            const SizedBox(width: 24),
            _StatusItem(icon: Icons.timer_outlined, label: '本次写作', value: state.sessionDuration),
          ],
          const SizedBox(width: 24),
          // 今日累计（点击打开统计趋势）
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => showWritingStatsDialog(context),
              child: _StatusItem(icon: Icons.today_outlined, label: '今日', value: '$todayCount'),
            ),
          ),
          if (dailyGoal > 0) ...[
            const SizedBox(width: 24),
            // 每日目标进度（点击设置目标）
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showGoalDialog(context, dailyGoal),
                child: _GoalProgress(todayCount: todayCount, goal: dailyGoal, theme: theme),
              ),
            ),
          ] else ...[
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showGoalDialog(context, dailyGoal),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '设每日目标',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          _buildContextStatus(ref, theme),
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).setMode(next);
            },
            tooltip: '切换主题',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// 今日累计写作字数（随 writingStatsRefreshProvider 刷新）
final todayWordCountProvider = FutureProvider<int>((ref) async {
  ref.watch(writingStatsRefreshProvider);
  final sessionDao = ref.read(sessionDaoProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return sessionDao.getWordCountSince(todayStart);
});

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

Widget _buildContextStatus(WidgetRef ref, ThemeData theme) {
  final selectedCount = ref.watch(selectedContextChaptersProvider).length;
  if (selectedCount == 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.checklist, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          '已选 $selectedCount 章',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
        ),
      ],
    ),
  );
}

/// 每日目标进度（文字 + 迷你进度条 + 达成标识）
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.todayCount, required this.goal, required this.theme});

  final int todayCount;
  final int goal;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final reached = todayCount >= goal;
    final progress = (todayCount / goal).clamp(0.0, 1.0).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          reached ? Icons.emoji_events : Icons.flag_outlined,
          size: 14,
          color: reached ? Colors.amber : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          reached ? '$goal 达成!' : '$todayCount/$goal',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: reached ? Colors.amber : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: reached ? Colors.amber : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.tune, size: 12, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

/// 每日目标设置对话框
Future<void> _showGoalDialog(BuildContext context, int currentGoal) async {
  final controller = TextEditingController(text: currentGoal > 0 ? '$currentGoal' : '');
  const presets = [2000, 3000, 5000, 10000];

  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('每日写作目标'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('设定每日目标字数，状态栏显示进度，达成后自动高亮🎉', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '目标字数', hintText: '如 3000'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: presets.map((p) {
              return ActionChip(
                label: Text('$p'),
                onPressed: () {
                  controller.text = '$p';
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 0),
          child: const Text('不设目标'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
          child: const Text('保存'),
        ),
      ],
    ),
  );

  if (result != null && context.mounted) {
    ProviderScope.containerOf(context, listen: false).read(dailyGoalProvider.notifier).setGoal(result);
    if (result > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('每日目标已设置为 $result 字'), duration: const Duration(seconds: 2)),
      );
    }
  }
}
