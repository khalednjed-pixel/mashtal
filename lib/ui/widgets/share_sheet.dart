import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../logic/share.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'pickup_pass.dart' show openExternal;

/// Share a plant: send it on WhatsApp or copy its link. The message carries
/// the plant's name, its lowest price and a link that opens its page.
Future<void> sharePlant(BuildContext context, {required Plant plant, double? fromPrice}) {
  final lang = context.lang;
  final link = plantLink(plant.id);
  final message = shareMessage(lang: lang, plantName: plant.name(lang), fromPrice: fromPrice, link: link);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sheet.tr('sharePlant'), style: text.titleLarge),
              const SizedBox(height: MashtalSpace.md),
              // A preview of what the other person receives.
              Container(
                key: const Key('sharePreview'),
                padding: const EdgeInsets.all(MashtalSpace.md),
                decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                child: Text(message, style: text.bodyMedium),
              ),
              const SizedBox(height: MashtalSpace.lg),
              FilledButton.icon(
                key: const Key('shareWhatsApp'),
                icon: const Icon(Icons.chat_outlined),
                label: Text(sheet.tr('shareWhatsApp')),
                onPressed: () {
                  Navigator.pop(sheet);
                  openExternal(whatsAppShare(message));
                },
              ),
              const SizedBox(height: MashtalSpace.sm),
              OutlinedButton.icon(
                key: const Key('copyLink'),
                icon: const Icon(Icons.link),
                label: Text(sheet.tr('copyLink')),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final done = sheet.tr('linkCopied');
                  Navigator.pop(sheet);
                  await Clipboard.setData(ClipboardData(text: message));
                  messenger.showSnackBar(SnackBar(content: Text(done), duration: const Duration(seconds: 2)));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
