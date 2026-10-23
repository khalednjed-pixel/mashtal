import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../logic/phone.dart';

String? requiredField(BuildContext context, String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;

String? phoneField(BuildContext context, String? v) => SaudiPhone.normalize(v ?? '') == null ? context.tr('err.invalid-phone') : null;

/// Banner reminding the admin that new partners start hidden (US-03 AC-01).
class PendingNote extends StatelessWidget {
  const PendingNote({super.key});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF0C9),
        child: ListTile(leading: const Icon(Icons.info_outline), title: Text(context.tr('newPartnerPending'))),
      );
}
