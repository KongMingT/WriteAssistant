import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/database/providers.dart';
import '../../core/utils/id_generator.dart';
import '../workspace/models/selection_state.dart';

void showCharacterSheet(BuildContext context, WidgetRef ref) {
  final bookId = ref.read(selectedBookProvider);
  if (bookId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先选择一本书'), duration: Duration(seconds: 2)),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ProviderScope(
      overrides: [],
      child: _CharacterSheet(bookId: bookId),
    ),
  );
}

class _CharacterSheet extends ConsumerStatefulWidget {
  final String bookId;
  const _CharacterSheet({required this.bookId});

  @override
  ConsumerState<_CharacterSheet> createState() => _CharacterSheetState();
}

class _CharacterSheetState extends ConsumerState<_CharacterSheet> {
  List<Character> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = ref.read(characterDaoProvider);
    _characters = await dao.getCharactersByBook(widget.bookId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _editCharacter({Character? character}) async {
    final result = await showDialog<Character?>(
      context: context,
      builder: (_) => CharacterEditDialog(character: character),
    );
    if (result != null) {
      final dao = ref.read(characterDaoProvider);
      final now = DateTime.now();
      if (character == null) {
        await dao.insertCharacter(CharactersCompanion(
          id: Value(result.id), bookId: Value(widget.bookId),
          name: Value(result.name), gender: Value(result.gender ?? ''),
          age: Value(result.age ?? ''), personality: Value(result.personality ?? ''),
          background: Value(result.background ?? ''), appearance: Value(result.appearance ?? ''),
          roleType: Value(result.roleType), notes: Value(result.notes ?? ''),
          createdAt: Value(now), updatedAt: Value(now),
        ));
      } else {
        await dao.updateCharacter(result);
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookDao = ref.read(bookDaoProvider);
    return FutureBuilder<Book?>(
      future: bookDao.getBookById(widget.bookId),
      builder: (context, snapshot) {
        final bookTitle = snapshot.data?.title ?? '未知书籍';
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖拽指示条
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 32, height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Icon(Icons.people_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('《$bookTitle》- 人物管理',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: '新建人物',
                        onPressed: () => _editCharacter(),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 内容
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _characters.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 40,
                                      color: theme.colorScheme.primary.withAlpha(60)),
                                  const SizedBox(height: 8),
                                  Text('暂无人物', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _editCharacter(),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('新建人物'),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              children: _characters.map((c) => _buildCard(c, theme)).toList(),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCard(Character c, ThemeData theme) {
    final roleLabel = {'protagonist': '主角', 'antagonist': '反派', 'supporting': '配角'}[c.roleType] ?? c.roleType;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _editCharacter(character: c),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: c.roleType == 'protagonist'
                  ? Colors.blue.withAlpha(30)
                  : c.roleType == 'antagonist'
                      ? Colors.red.withAlpha(30)
                      : Colors.grey.withAlpha(30),
              child: Text(c.name.isNotEmpty ? c.name[0] : '?', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    _tag(roleLabel, theme),
                    if (c.gender != null && c.gender!.isNotEmpty) ...[const SizedBox(width: 4), _tag(c.gender!, theme)],
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer)),
    );
  }
}

// ===== 人物编辑对话框 =====

class CharacterEditDialog extends StatefulWidget {
  final Character? character;
  const CharacterEditDialog({super.key, this.character});

  @override
  State<CharacterEditDialog> createState() => _CharacterEditDialogState();
}

class _CharacterEditDialogState extends State<CharacterEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _genderCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _backgroundCtrl;
  late TextEditingController _appearanceCtrl;
  late TextEditingController _notesCtrl;
  String _roleType = 'supporting';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _genderCtrl = TextEditingController(text: c?.gender ?? '');
    _ageCtrl = TextEditingController(text: c?.age ?? '');
    _personalityCtrl = TextEditingController(text: c?.personality ?? '');
    _backgroundCtrl = TextEditingController(text: c?.background ?? '');
    _appearanceCtrl = TextEditingController(text: c?.appearance ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _roleType = c?.roleType ?? 'supporting';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genderCtrl.dispose();
    _ageCtrl.dispose();
    _personalityCtrl.dispose();
    _backgroundCtrl.dispose();
    _appearanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.character == null ? '新建人物' : '编辑人物'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '姓名 *'), validator: (v) => v?.isEmpty == true ? '必填' : null),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _roleType,
                  decoration: const InputDecoration(labelText: '角色类型', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'protagonist', child: Text('主角')),
                    DropdownMenuItem(value: 'antagonist', child: Text('反派')),
                    DropdownMenuItem(value: 'supporting', child: Text('配角')),
                  ],
                  onChanged: (v) => setState(() => _roleType = v ?? 'supporting'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(controller: _genderCtrl, decoration: const InputDecoration(labelText: '性别', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _ageCtrl, decoration: const InputDecoration(labelText: '年龄', isDense: true))),
                ]),
                const SizedBox(height: 8),
                TextFormField(controller: _personalityCtrl, decoration: const InputDecoration(labelText: '性格'), maxLines: 2),
                const SizedBox(height: 8),
                TextFormField(controller: _backgroundCtrl, decoration: const InputDecoration(labelText: '背景故事'), maxLines: 2),
                const SizedBox(height: 8),
                TextFormField(controller: _appearanceCtrl, decoration: const InputDecoration(labelText: '外貌'), maxLines: 2),
                const SizedBox(height: 8),
                TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: '备注'), maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final result = Character(
      id: widget.character?.id ?? generateId(),
      bookId: widget.character?.bookId ?? '',
      name: _nameCtrl.text,
      gender: _genderCtrl.text.isEmpty ? null : _genderCtrl.text,
      age: _ageCtrl.text.isEmpty ? null : _ageCtrl.text,
      personality: _personalityCtrl.text.isEmpty ? null : _personalityCtrl.text,
      background: _backgroundCtrl.text.isEmpty ? null : _backgroundCtrl.text,
      appearance: _appearanceCtrl.text.isEmpty ? null : _appearanceCtrl.text,
      roleType: _roleType,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      createdAt: widget.character?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, result);
  }
}
