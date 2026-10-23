import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../widgets/common.dart';

/// Placeholder tab so the nursery navigation is complete; filled in Sprint 3.
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('reservations')), actions: const [LanguageButton()]),
        body: EmptyState(icon: Icons.receipt_long_outlined, title: context.tr('reservationsSoon')),
      );
}
