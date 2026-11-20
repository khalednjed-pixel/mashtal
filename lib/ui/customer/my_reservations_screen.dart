import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reservation_card.dart';

/// The customer's reservations with their status (US-16 AC-02): an accepted
/// one shows until when it is held, a rejected one shows the reason.
class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.backend.reservations;
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('myReservations')), actions: const [LanguageButton()]),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.event_available,
              title: context.tr('noReservations'),
              actions: [OutlinedButton(onPressed: () => context.go('/shop'), child: Text(context.tr('buyPlants')))],
            )
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.all(MashtalSpace.screen)),
                children: [
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MashtalSpace.md),
                      child: ReservationCard(
                        reservation: r,
                        title: app.backend.nurseryById(r.nurseryId)?.name(lang) ?? '',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
