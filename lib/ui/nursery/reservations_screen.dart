import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reservation_card.dart';

/// The nursery's reservation requests (US-17): accept a pending one, which
/// starts the 48-hour hold, or reject it with a reason the customer sees.
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.backend.reservations;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reservations')), actions: const [LanguageButton()]),
      body: list.isEmpty
          ? EmptyState(icon: Icons.receipt_long_outlined, title: context.tr('noReservations'))
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.all(MashtalSpace.screen)),
                children: [
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MashtalSpace.md),
                      child: ReservationCard(
                        reservation: r,
                        title: r.customerName,
                        subtitle: r.customerPhone,
                        actions: [
                          if (r.status == ReservationStatus.pending) ...[
                            OutlinedButton(
                              key: Key('reject-${r.id}'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(88, 40)),
                              onPressed: () => _reject(context, app, r),
                              child: Text(context.tr('reject')),
                            ),
                            FilledButton(
                              key: Key('accept-${r.id}'),
                              style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                              onPressed: () => trySave(context, () => app.backend.acceptReservation(r.id)),
                              child: Text(context.tr('accept')),
                            ),
                          ],
                          if (r.status == ReservationStatus.accepted && !r.isExpired(DateTime.now()))
                            FilledButton.icon(
                              key: Key('pickedUp-${r.id}'),
                              style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                              icon: const Icon(Icons.handshake_outlined),
                              label: Text(context.tr('markPickedUp')),
                              onPressed: () => _pickedUp(context, app, r),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _pickedUp(BuildContext context, AppState app, Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.yard_outlined),
        title: Text(c.tr('pickedUpConfirmTitle')),
        content: Text(c.tr('pickedUpConfirmBody').replaceAll('{name}', r.customerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
          FilledButton(
            key: const Key('confirmPickedUp'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('confirmPickedUp')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await trySave(context, () => app.backend.markPickedUp(r.id));
  }

  Future<void> _reject(BuildContext context, AppState app, Reservation r) async {
    final reason = await showDialog<RejectReason>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('rejectWhy')),
        children: [
          for (final reason in RejectReason.values)
            SimpleDialogOption(
              key: Key('reason-${reason.name}'),
              onPressed: () => Navigator.pop(c, reason),
              child: Text(c.tr('reason.${reason.name}')),
            ),
        ],
      ),
    );
    if (reason != null && context.mounted) await trySave(context, () => app.backend.rejectReservation(r.id, reason));
  }
}
