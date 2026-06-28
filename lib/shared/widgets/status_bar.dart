import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/models/selection_state.dart';
import '../themes/theme_provider.dart';

/// 底部状态栏 - 显示字数、码字速度等
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(writingStateProvider);
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
          const Spacer(),
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
