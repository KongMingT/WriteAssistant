import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/providers.dart';

/// 写作统计/趋势对话框 - 显示最近 N 天字数趋势
class WritingStatsDialog extends ConsumerStatefulWidget {
  const WritingStatsDialog({super.key});

  @override
  ConsumerState<WritingStatsDialog> createState() => _WritingStatsDialogState();
}

class _WritingStatsDialogState extends ConsumerState<WritingStatsDialog> {
  int _days = 7;
  List<({DateTime day, int words})> _daily = [];
  bool _loading = true;

  static const _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessionDao = ref.read(sessionDaoProvider);
    final daily = await sessionDao.getDailyWordCounts(_days);
    if (mounted) {
      setState(() {
      _daily = daily;
      _loading = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _daily.fold<int>(0, (sum, d) => sum + d.words);
    final max = _daily.fold<int>(0, (max, d) => d.words > max ? d.words : max);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bar_chart, size: 20),
          SizedBox(width: 8),
          Text('写作统计'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('近7天')),
                    ButtonSegment(value: 30, label: Text('近30天')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (v) {
                    setState(() => _days = v.first);
                    _load();
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              Text('累计写作 $total 字', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _daily.map((d) {
                    final ratio = max == 0 ? 0.0 : d.words / max;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              d.words == 0 ? '' : _compact(d.words),
                              style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: 6 + ratio * 80,
                              decoration: BoxDecoration(
                                color: d.words == 0
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dayLabel(d.day),
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('日均 ${total ~/ _daily.length} 字',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    return '周${_weekDays[day.weekday - 1]}';
  }

  String _compact(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// 弹出写作统计对话框
Future<void> showWritingStatsDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const WritingStatsDialog());
}