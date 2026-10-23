import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// My Garden is signed-in only (US-01 AC-02). Its plant cards come in Sprint 3.
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('myGarden')), actions: const [LanguageButton()]),
      body: EmptyState(
        icon: Icons.yard_outlined,
        title: '${context.tr('welcome')} ${user?.name ?? ''}. ${context.tr('gardenEmpty')}',
        body: context.tr('gardenSoon'),
        actions: [FilledButton.tonal(onPressed: () => context.go('/shop'), child: Text(context.tr('buyPlants')))],
      ),
    );
  }
}
