import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    // Rebuilt once after sign-out, before the router leaves this page.
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('account')), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(user.name.characters.first)),
                title: Text(user.name, style: theme.textTheme.titleMedium),
                subtitle: Text('${user.phone} · ${context.trCity(user.city)}', textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                trailing: Chip(label: Text(roleLabel(context.lang, user.role))),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const Key('editProfile'),
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.tr('editProfile')),
                subtitle: Text(context.tr('cityDefaultHint')),
                onTap: () => showDialog<void>(context: context, builder: (_) => _EditProfileDialog(app: app)),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(context.tr('language')),
                    trailing: Text(context.tr('switchLanguage')),
                    onTap: () => app.toggleLanguage(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: Text(context.tr('resetDemo')),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final done = context.tr('resetDone');
                      await app.resetDemo();
                      messenger.showSnackBar(SnackBar(content: Text(done)));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('signOut'),
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    title: Text(context.tr('signOut'), style: TextStyle(color: theme.colorScheme.error)),
                    onTap: () async {
                      await app.backend.signOut();
                      if (context.mounted) context.go('/shop');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.app});
  final AppState app;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _name = TextEditingController(text: widget.app.user!.name);
  late String _city = cityIds.contains(widget.app.user!.city) ? widget.app.user!.city : cityIds.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('editProfile')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(key: const Key('profileName'), controller: _name, decoration: InputDecoration(labelText: context.tr('name'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('profileCity'),
            initialValue: _city,
            decoration: InputDecoration(labelText: context.tr('city')),
            items: [for (final c in cityIds) DropdownMenuItem(value: c, child: Text(context.trCity(c)))],
            onChanged: (v) => setState(() => _city = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
        FilledButton(
          key: const Key('saveProfile'),
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            await widget.app.backend.updateProfile(name: _name.text, city: _city);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
