import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/care_plan.dart';
import '../../logic/text_match.dart';
import '../../logic/watering.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/home_picker.dart';
import '../widgets/plant_photo.dart';

/// Adds a plant bought outside the app to My Garden (US-21 AC-02 empty
/// state). For now the customer picks it from the plant list by name;
/// identifying it by photo comes with the photo check.
class GardenAddScreen extends StatefulWidget {
  const GardenAddScreen({super.key});

  @override
  State<GardenAddScreen> createState() => _GardenAddScreenState();
}

class _GardenAddScreenState extends State<GardenAddScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final plants = [
      for (final p in app.backend.plants)
        if (_query.trim().isEmpty || matchesQuery(_query, [p.nameAr, p.nameEn, p.scientificName])) p,
    ]..sort((a, b) => a.name(lang).compareTo(b.name(lang)));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/garden')),
        title: Text(context.tr('addManually')),
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        child: ListView(
          padding: clearNav(context, const EdgeInsets.fromLTRB(MashtalSpace.screen, MashtalSpace.xs, MashtalSpace.screen, MashtalSpace.xl)),
          children: [
            Text(context.tr('addManuallyBody'), style: text.bodyMedium),
            const SizedBox(height: MashtalSpace.md),
            TextField(
              key: const Key('gardenSearch'),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('gardenSearchHint')),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: MashtalSpace.md),
            if (plants.isEmpty)
              Padding(
                padding: const EdgeInsets.all(MashtalSpace.xl),
                child: Text(context.tr('noResults'), style: text.bodyMedium),
              ),
            for (final p in plants)
              Padding(
                padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                child: Card(
                  child: ListTile(
                    key: Key('pick-${p.id}'),
                    leading: PlantPhoto(plant: p, size: 48),
                    title: Text(p.name(lang)),
                    subtitle: Text(wateringEveryText(lang, p.wateringEveryDays)),
                    trailing: const Icon(Icons.add_circle_outline, color: MashtalColors.leaf),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.of(context);
                      final msg = '${context.tr('addedToGarden')}: ${p.name(lang)}';
                      // One question, with our guess already selected, so
                      // watering fits the pot or the ground from day one. The
                      // sheet saves and stays open if saving fails.
                      final home = await pickHome(
                        context,
                        current: guessHome(p),
                        guessed: true,
                        onConfirm: (h) => app.backend.addToGarden(p.id, home: h),
                      );
                      if (home == null) return;
                      router.go('/garden');
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
