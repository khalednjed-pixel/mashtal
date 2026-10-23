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
