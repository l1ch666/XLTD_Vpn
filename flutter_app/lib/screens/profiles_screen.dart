import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/profile_row.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профили'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(context, app, null),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Добавить профиль',
          ),
        ],
      ),
      body: app.profiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Профилей пока нет. Нажмите + чтобы добавить olcrtc://… ссылку.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: app.profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = app.profiles[i];
                return ProfileRow(
                  profile: p,
                  active: p.id == app.activeProfile?.id,
                  onTap: () => app.selectProfile(p),
                  onLongPress: () => _confirmDelete(context, app, p),
                );
              },
            ),
    );
  }

  void _openEditor(BuildContext context, AppState app, Profile? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _ProfileEditor(existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState app, Profile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: Text(p.comment.isEmpty ? p.link : p.comment),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.err)),
          ),
        ],
      ),
    );
    if (ok == true) await app.deleteProfile(p.id);
  }
}

class _ProfileEditor extends StatefulWidget {
  final Profile? existing;
  const _ProfileEditor({this.existing});

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _link;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _link = TextEditingController(text: widget.existing?.link ?? '');
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<AppState>()
          .upsertFromLink(_link.text.trim(), id: widget.existing?.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('FormatException: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Новый профиль'
          : 'Изменить профиль'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _link,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'olcrtc://carrier?transport@room#hex\$comment',
                labelText: 'Ссылка',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) _link.text = data!.text!.trim();
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Вставить'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.err, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
