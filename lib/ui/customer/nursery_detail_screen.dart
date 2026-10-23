import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/not_found.dart';

/// A verified nursery and the plants it lists.
class NurseryDetailScreen extends StatelessWidget {
  const NurseryDetailScreen({super.key, required this.nurseryId});
  final String nurseryId;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<AppState>().backend;
    final nursery = market.nurseryById(nurseryId);
    // Customers never see unverified nurseries (US-03 AC-01).
    if (nursery == null || !nursery.isVerified) return const NotFoundScreen();
    final lang = context.lang;
    final theme = Theme.of(context);
    final listings = market.listings.where((l) => l.nurseryId == nurseryId && !l.hidden).toList()
      ..sort((a, b) => (b.isAvailable ? 1 : 0) - (a.isAvailable ? 1 : 0));

    return Scaffold(
      appBar: AppBar(title: Text(nursery.name(lang)), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(nursery.name(lang), style: theme.textTheme.titleLarge)),
                        RatingLabel(rating: nursery.rating, count: nursery.ratingCount),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${context.trCity(nursery.city)} · ${context.tr('district')}: ${nursery.district}'),
                    Text('${context.tr('hours')}: ${nursery.hours}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('${context.tr('plants')} (${listings.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final l in listings)
              if (market.plantById(l.plantId) case final plant?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: PlantAvatar(plant: plant, size: 44),
                      title: Text(plant.name(lang)),
                      subtitle: Text(l.isAvailable ? context.tr('inStock') : context.tr('notAvailable'),
                          style: TextStyle(color: l.isAvailable ? null : theme.colorScheme.error)),
                      trailing: Text(formatPrice(context, l.price)),
                      onTap: () => context.go('/shop/plant/${plant.id}'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
