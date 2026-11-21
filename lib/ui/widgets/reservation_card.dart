import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// One reservation: who or where, the plants, the total and its status.
/// [title] is the nursery for a customer, the customer for a nursery.
class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation, required this.title, this.subtitle, this.actions = const [], this.footer});

  final Reservation reservation;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shown under everything else, e.g. the pickup pass.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final market = context.read<AppState>().backend;
    final lang = context.lang;
    final text = Theme.of(context).textTheme;
    final when = DateFormat('d MMM, HH:mm', lang);
    final expired = r.isExpired(DateTime.now());
    return Card(
      key: Key('reservation-${r.id}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
      child: Padding(
        padding: const EdgeInsets.all(MashtalSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                ReservationStatusChip(status: r.status, expired: expired),
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: text.bodySmall?.copyWith(color: MashtalColors.muted), textDirection: TextDirection.ltr, textAlign: TextAlign.start),
            const SizedBox(height: MashtalSpace.sm),
            for (final i in r.items)
              Text(
                '${market.plantById(i.plantId)?.name(lang) ?? i.plantId} × ${i.quantity} · ${formatPrice(context, i.price * i.quantity)}',
                style: text.bodyMedium,
              ),
            const SizedBox(height: MashtalSpace.xs),
            Text('${formatPrice(context, r.total)} · ${when.format(r.createdAt.toLocal())}', style: text.bodySmall?.copyWith(color: MashtalColors.muted)),
            if (r.status == ReservationStatus.accepted && !expired)
              Padding(
                padding: const EdgeInsets.only(top: MashtalSpace.xs),
                child: Text(
                  '${context.tr('heldUntil')} ${when.format(r.expiresAt!.toLocal())}',
                  key: Key('heldUntil-${r.id}'),
                  style: text.bodyMedium?.copyWith(color: MashtalColors.forestDeep),
                ),
              ),
            if (r.status == ReservationStatus.pickedUp && r.pickedUpAt != null)
              Padding(
                padding: const EdgeInsets.only(top: MashtalSpace.xs),
                child: Row(
                  children: [
                    const Icon(Icons.yard_outlined, size: 18, color: MashtalColors.leaf),
                    const SizedBox(width: MashtalSpace.xs),
                    Expanded(
                      child: Text(
                        // The customer is told where the plants went; the nursery only when.
                        context
                            .tr(context.read<AppState>().role == Role.customer ? 'inYourGarden' : 'collectedOn')
                            .replaceAll('{date}', when.format(r.pickedUpAt!.toLocal())),
                        key: Key('inGarden-${r.id}'),
                        style: text.bodyMedium?.copyWith(color: MashtalColors.forestDeep),
                      ),
                    ),
                  ],
                ),
              ),
            if (r.status == ReservationStatus.rejected && r.rejectReason != null)
              Padding(
                padding: const EdgeInsets.only(top: MashtalSpace.xs),
                child: Text(
                  '${context.tr('rejectReason')}: ${context.tr('reason.${r.rejectReason!.name}')}',
                  key: Key('rejectReason-${r.id}'),
                  style: text.bodyMedium?.copyWith(color: MashtalColors.error),
                ),
              ),
            ?footer,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: MashtalSpace.sm),
              Wrap(spacing: MashtalSpace.sm, alignment: WrapAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class ReservationStatusChip extends StatelessWidget {
  const ReservationStatusChip({super.key, required this.status, this.expired = false});
  final ReservationStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final key = expired ? 'expired' : status.name;
    final (bg, fg) = switch ((status, expired)) {
      (_, true) || (ReservationStatus.rejected, _) => (MashtalColors.errorSoft, MashtalColors.error),
      (ReservationStatus.accepted || ReservationStatus.pickedUp, _) => (MashtalColors.mint, MashtalColors.forestDeep),
      _ => (MashtalColors.ground, MashtalColors.forestDeep),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.xs),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(context.tr('res.$key'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
