import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_client.dart';
import '../../core/ai/models/ai_model_config.dart';
import '../workspace/models/selection_state.dart';

/// 设置页面 - API Key 配置
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<AiProvider, TextEditingController> _keyControllers = {};
  AiProvider _activeProvider = AiProvider.deepseek;
  bool _isLoading = true;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    for (final p in AiProvider.values) {
      _keyControllers[p] = TextEditingController();
    }
    _loadSettings();
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _activeProvider = await getActiveProvider();
    for (final p in AiProvider.values) {
      final key = await getApiKey(p);
      if (key != null) {
        _keyControllers[p]?.text = key;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveKey(AiProvider provider) async {
    final key = _keyControllers[provider]?.text ?? '';
    if (key.isNotEmpty) {
      await saveApiKey(provider, key);
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${provider.displayName} API Key 已保存')),
        );
      }
    }
  }

  Future<void> _deleteKey(AiProvider provider) async {
    await deleteApiKey(provider);
    _keyControllers[provider]?.clear();
    ref.invalidate(aiConfigProvider);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.displayName} API Key 已删除')),
      );
    }
  }

  Future<void> _setActive(AiProvider provider) async {
    await setActiveProvider(provider);
    ref.invalidate(aiConfigProvider);
    if (mounted) {
      setState(() => _activeProvider = provider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换至 ${provider.displayName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('AI 模型配置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('自行填写 API Key，Key 仅加密保存在本地设备中',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                ...AiProvider.values.map((p) => _buildProviderCard(p, theme)),
                const SizedBox(height: 32),
                Text('AI 对话上下文', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('AI 助手自动携带选中的章节内容作为背景',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _buildContextConfig(theme),
                const SizedBox(height: 32),
                Text('获取 API Key', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildInfoTile('DeepSeek', 'https://platform.deepseek.com/api_keys', theme),
                _buildInfoTile('通义千问', 'https://dashscope.console.aliyun.com/apiKey', theme),
                _buildInfoTile('Moonshot', 'https://platform.moonshot.cn/console/api-keys', theme),
                if (AiProvider.values.any((p) => _keyControllers[p]?.text.isNotEmpty == true))
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _testConnection,
                        icon: const Icon(Icons.wifi_find, size: 18),
                        label: const Text('测试连接'),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                Text('提示', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('主题切换、字号和字体设置已移至编辑区顶部工具栏', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
    );
  }

  Widget _buildProviderCard(AiProvider provider, ThemeData theme) {
    final hasKey = _keyControllers[provider]?.text.isNotEmpty == true;
    final isActive = provider == _activeProvider;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: hasKey ? Colors.green : Colors.grey)),
              const SizedBox(width: 8),
              Expanded(child: Text(provider.displayName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Text('当前', style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
                ),
              if (!isActive && hasKey)
                TextButton(onPressed: () => _setActive(provider), child: const Text('切换到此模型')),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _keyControllers[provider],
              obscureText: _obscureText,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    if (hasKey)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteKey(provider),
                        tooltip: '删除 Key',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              onSubmitted: (_) => _saveKey(provider),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: hasKey ? () => _saveKey(provider) : null,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextConfig(ThemeData theme) {
    final config = ref.watch(aiContextConfigProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('选章上限', style: theme.textTheme.bodyMedium),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 5, label: Text('5 章')),
                    ButtonSegment(value: 10, label: Text('10 章')),
                  ],
                  selected: {config.maxChapters},
                  onSelectionChanged: (v) {
                    ref.read(aiContextConfigProvider.notifier).state =
                        AiContextConfig(maxChapters: v.first, maxChars: config.maxChars);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('字数上限: 20000 字（固定）', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String name, String url, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('$name — ', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
        Expanded(child: Text(url, style: TextStyle(fontSize: 13, color: theme.colorScheme.primary), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Future<void> _testConnection() async {
    final activeProvider = await getActiveProvider();
    final apiKey = await getApiKey(activeProvider);
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先填写并保存 API Key')));
      return;
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在测试连接...')));
    try {
      final client = AiClient();
      await client.chat(
        provider: activeProvider,
        apiKey: apiKey,
        messages: [const AiMessage(role: 'user', content: '回复"连接成功"')],
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 连接成功！'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 连接失败: $e'), backgroundColor: Colors.red));
    }
  }
}
