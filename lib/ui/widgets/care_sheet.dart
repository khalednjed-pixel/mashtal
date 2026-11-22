import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';

/// Services offered from a plant in My Garden (US-23 AC-01).
const careServices = [ServiceType.pruning, ServiceType.periodicCare, ServiceType.treatment];

IconData careIcon(ServiceType s) => switch (s) {
      ServiceType.pruning => Icons.content_cut,
      ServiceType.periodicCare => Icons.event_repeat,
      ServiceType.treatment => Icons.healing_outlined,
      ServiceType.planting => Icons.grass,
    };

/// Asks what the plant needs, then opens the professionals list filtered by
/// that service (US-23).
Future<void> bookPlantCare(BuildContext context, {required GardenPlant garden, required String plantName}) async {
  final router = GoRouter.of(context);
  final service = await showModalBottomSheet<ServiceType>(
    context: context,
    showDragHandle: true,
    backgroundColor: MashtalColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MashtalSpace.cardRadius))),
    builder: (c) {
      final text = Theme.of(c).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MashtalSpace.screen, 0, MashtalSpace.screen, MashtalSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.tr('whatNeeds').replaceAll('{plant}', plantName), style: text.titleLarge),
              const SizedBox(height: MashtalSpace.md),
              for (final s in careServices)
                Padding(
                  padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                  child: Material(
                    color: MashtalColors.ground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MashtalSpace.radius)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('care-${s.name}'),
                      onTap: () => Navigator.pop(c, s),
                      child: Padding(
                        padding: const EdgeInsets.all(MashtalSpace.md),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: MashtalColors.surface, shape: BoxShape.circle),
                              child: Icon(careIcon(s), color: MashtalColors.forest),
                            ),
                            const SizedBox(width: MashtalSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.trEnum(s), style: text.titleMedium),
                                  Text(c.tr('svc.${s.name}'), style: text.bodySmall),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: MashtalColors.leaf, textDirection: TextDirection.ltr),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (service == null) return;
  router.go(Uri(path: '/garden/care', queryParameters: {'service': service.name, 'plant': garden.id}).toString());
}
