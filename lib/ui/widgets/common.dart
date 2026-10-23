import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// Coloured icon standing in for a plant photo until real photos are added.
class PlantAvatar extends StatelessWidget {
  const PlantAvatar({super.key, required this.plant, this.size = 56});

  final Plant plant;
  final double size;

  static IconData iconFor(PlantCategory c) => switch (c) {
        PlantCategory.tree => Icons.park,
        PlantCategory.palm => Icons.forest,
        PlantCategory.shrub => Icons.grass,
        PlantCategory.climber => Icons.local_florist,
        PlantCategory.succulent => Icons.spa,
        PlantCategory.groundcover => Icons.texture,
        PlantCategory.grass => Icons.grass_outlined,
        PlantCategory.herb => Icons.eco,
        PlantCategory.houseplant => Icons.filter_vintage,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(size / 4)),
      child: Icon(iconFor(plant.category), color: scheme.onPrimaryContainer, size: size * 0.55),
    );
  }
}

class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.rating, this.count});
  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A100)),
          const SizedBox(width: 2),
          Text(rating == 0 ? '—' : rating.toStringAsFixed(1)),
          if (count != null && count! > 0) Text(' ($count)', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final PartnerStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      PartnerStatus.verified => (const Color(0xFFDDF0E1), const Color(0xFF1D5A2C)),
      PartnerStatus.pending => (const Color(0xFFFFF0C9), const Color(0xFF7A5600)),
      PartnerStatus.suspended => (const Color(0xFFFADAD7), const Color(0xFF8C1D12)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(context.trEnum(status), style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 13)),
    );
  }
}

String formatPrice(BuildContext context, double price) {
  final value = price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  return '$value ${context.tr('sar')}';
}

/// App bar action that switches between Arabic and English.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.read<AppState>().toggleLanguage(),
        child: Text(context.tr('switchLanguage')),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.actions = const []});

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            for (final a in actions) ...[const SizedBox(height: 12), a],
          ],
        ),
      ),
    );
  }
}

/// Keeps content readable on wide screens (the web build).
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
