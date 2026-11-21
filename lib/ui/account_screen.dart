import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/garden_art.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    // A guest gets a sign-in prompt here instead of the sign-in screen.
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('account')), actions: const [LanguageButton()]),
        body: SignInPrompt(icon: Icons.person_outline, body: context.tr('guestAccountBody'), from: '/account'),
      );
    }
    final theme = Theme.of(context);
    final market = app.backend;
    final customer = user.role == Role.customer;
    final unseen = app.unseenCount(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('account')), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            _ProfileCard(user: user),
            if (customer) ...[
              const SizedBox(height: MashtalSpace.md),
              // Their garden, saved plants and reservations at a glance.
              Row(
                children: [
                  _CountTile(art: Art.sprout, count: market.garden.length, label: context.tr('myGarden'), onTap: () => context.go('/garden')),
                  const SizedBox(width: MashtalSpace.sm),
                  _CountTile(art: Art.savedLeaf, count: app.savedPlantIds.length, label: context.tr('savedPlants'), onTap: () => context.go('/saved')),
                  const SizedBox(width: MashtalSpace.sm),
                  _CountTile(art: Art.basket, count: market.reservations.length, label: context.tr('myReservations'), onTap: () => context.go('/reservations')),
                ],
              ),
              const SizedBox(height: MashtalSpace.lg),
              _Group(children: [
                _Row(key: const Key('myReservations'), icon: Icons.event_available_outlined, title: context.tr('myReservations'), onTap: () => context.go('/reservations')),
                // US-19: reservation notices, with the unseen count.
                _Row(
                  key: const Key('notifications'),
                  icon: Icons.notifications_none,
                  title: context.tr('notifications'),
                  trailing: unseen > 0 ? Badge(label: Text('$unseen'), key: const Key('unseenCount')) : null,
                  onTap: () => context.go('/notifications'),
                ),
                _Row(
                  key: const Key('savedPlants'),
                  icon: Icons.favorite_border,
                  title: context.tr('savedPlants'),
                  trailing: app.savedPlantIds.isEmpty ? null : Text('${app.savedPlantIds.length}', style: theme.textTheme.bodyMedium),
                  onTap: () => context.go('/saved'),
                ),
              ]),
            ],
            const SizedBox(height: MashtalSpace.lg),
            _Group(children: [
              _Row(
                key: const Key('editProfile'),
                icon: Icons.edit_outlined,
                title: context.tr('editProfile'),
                subtitle: context.tr('cityDefaultHint'),
                onTap: () => showDialog<void>(context: context, builder: (_) => _EditProfileDialog(app: app)),
              ),
              _Row(
                icon: Icons.translate,
                title: context.tr('language'),
                trailing: Text(context.tr('switchLanguage'), style: theme.textTheme.bodyMedium?.copyWith(color: MashtalColors.leaf)),
                onTap: () => app.toggleLanguage(),
              ),
              _Row(
                key: const Key('dataCredits'),
                icon: Icons.info_outline,
                title: context.tr('dataCredits'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(c.tr('dataCredits')),
                    content: Text(c.tr('dataCreditsBody')),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('close')))],
                  ),
                ),
              ),
              // Online the data is shared by everyone, so it is not reset.
              if (!market.isOnline)
                _Row(
                  icon: Icons.restart_alt,
                  title: context.tr('resetDemo'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final done = context.tr('resetDone');
                    await app.resetDemo();
                    messenger.showSnackBar(SnackBar(content: Text(done)));
                  },
                ),
            ]),
            const SizedBox(height: MashtalSpace.lg),
            _Group(children: [
              _Row(
                key: const Key('signOut'),
                icon: Icons.logout,
                title: context.tr('signOut'),
                danger: true,
                onTap: () async {
                  await market.signOut();
                  if (context.mounted) context.go('/shop');
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Who is signed in: initial, name, phone and city on the canopy green.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MashtalSpace.lg),
      decoration: BoxDecoration(color: MashtalColors.forest, borderRadius: BorderRadius.circular(MashtalSpace.cardRadius)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MashtalColors.lime, shape: BoxShape.circle),
            child: Text(user.name.characters.first, style: text.headlineSmall?.copyWith(color: MashtalColors.forest)),
          ),
          const SizedBox(width: MashtalSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: text.titleLarge?.copyWith(color: MashtalColors.surface)),
                Text(user.phone, textDirection: TextDirection.ltr, style: text.bodyMedium?.copyWith(color: MashtalColors.lime)),
                Text(context.trCity(user.city), style: text.bodyMedium?.copyWith(color: MashtalColors.lime)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.xs),
            decoration: BoxDecoration(border: Border.all(color: MashtalColors.lime), borderRadius: BorderRadius.circular(MashtalSpace.pill)),
            child: Text(roleLabel(context.lang, user.role), style: text.labelLarge?.copyWith(color: MashtalColors.lime)),
          ),
        ],
      ),
    );
  }
}

/// A count with its drawing, opening that place.
class _CountTile extends StatelessWidget {
  const _CountTile({required this.art, required this.count, required this.label, required this.onTap});
  final Art art;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Material(
        color: MashtalColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.cardRadius), side: const BorderSide(color: MashtalColors.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(MashtalSpace.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MashtalSpace.md, horizontal: MashtalSpace.xs),
            child: Column(
              children: [
                GardenArt(art, size: 40),
                const SizedBox(height: MashtalSpace.xs),
                Text('$count', style: text.headlineSmall?.copyWith(color: MashtalColors.forest)),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows grouped in one rounded panel, divided by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: MashtalColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.cardRadius), side: const BorderSide(color: MashtalColors.line)),
        child: Column(
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 68),
              c,
            ],
          ],
        ),
      );
}

/// One menu row: its icon in a mint disc, the title, and what is on the end.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, required this.onTap, this.subtitle, this.trailing, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = danger ? MashtalColors.error : MashtalColors.forest;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.lg, vertical: MashtalSpace.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: danger ? MashtalColors.errorSoft : MashtalColors.mint, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: MashtalSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyLarge?.copyWith(color: danger ? MashtalColors.error : null)),
                  if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                ],
              ),
            ),
            ?trailing,
            if (!danger) ...[const SizedBox(width: MashtalSpace.xs), const Icon(Icons.chevron_right, color: MashtalColors.leaf)],
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
