import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Professional home. Booking requests arrive in Sprint 4.
class ProHomeScreen extends StatelessWidget {
  const ProHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pro = app.backend.professionals.where((p) => p.id == app.user?.partnerId).firstOrNull;
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('jobs')), actions: const [LanguageButton()]),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pro != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(pro.name(lang), style: Theme.of(context).textTheme.titleLarge)),
                        StatusChip(status: pro.status),
                      ]),
                      const SizedBox(height: 8),
                      RatingLabel(rating: pro.rating),
                      Text('${pro.jobsDone} ${context.tr('jobsDone')}'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [for (final s in pro.services) Chip(label: Text(context.trEnum(s)))]),
                      Text('${context.tr('city')}: ${pro.cities.map(context.trCity).join('، ')}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            EmptyState(icon: Icons.handyman_outlined, title: context.tr('jobsSoon')),
          ],
        ),
      ),
    );
  }
}
