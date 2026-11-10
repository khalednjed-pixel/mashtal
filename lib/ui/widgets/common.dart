import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Icon on a ground-tinted tile, standing in for a plant photo.
class PlantAvatar extends StatelessWidget {
  const PlantAvatar({super.key, required this.plant, double this.size = 56});

  /// Fills its parent; the icon keeps a fixed size.
  const PlantAvatar.fill({super.key, required this.plant}) : size = null;

  final Plant plant;
  final double? size;

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
    final size = this.size;
    final icon = Icon(iconFor(plant.category), color: MashtalColors.leaf, size: size == null ? 48 : size * 0.5);
    if (size == null) return ColoredBox(color: MashtalColors.ground, child: Center(child: icon));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: MashtalColors.ground, borderRadius: BorderRadius.circular(MashtalSpace.radius)),
      child: icon,
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
          const Icon(Icons.star_rounded, size: 18, color: MashtalColors.leaf),
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
      PartnerStatus.verified => (MashtalColors.mint, MashtalColors.forestDeep),
      PartnerStatus.pending => (MashtalColors.ground, MashtalColors.forestDeep),
      PartnerStatus.suspended => (MashtalColors.errorSoft, MashtalColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MashtalSpace.md, vertical: MashtalSpace.xs),
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(side: status == PartnerStatus.pending ? const BorderSide(color: MashtalColors.line) : BorderSide.none),
      ),
      child: Text(context.trEnum(status), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
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
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('languageButton'),
        onPressed: () => context.read<AppState>().toggleLanguage(),
        icon: const Icon(Icons.translate, size: 18),
        // Names the language you switch to: "English" in Arabic, "العربية" in English.
        label: Text(context.tr('switchLanguage')),
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

/// Shown to a guest on a signed-in tab (My Garden, Account) instead of
/// jumping to the sign-in screen: says why, then offers the one sign-in page
/// (which comes back to [from] afterwards).
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.body, required this.from});

  final IconData icon;
  final String body;
  final String from;

  @override
  Widget build(BuildContext context) {
    final login = Uri(path: '/login', queryParameters: {'from': from}).toString();
    return EmptyState(
      icon: icon,
      title: context.tr('guestTitle'),
      body: body,
      actions: [
        FilledButton.icon(
          key: const Key('guestSignIn'),
          style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
          icon: const Icon(Icons.login),
          label: Text(context.tr('signIn')),
          onPressed: () => context.go(login),
        ),
      ],
    );
  }
}

/// Asks before taking [item] out of the cart. Returns true when the user confirms.
Future<bool> confirmRemoveFromCart(BuildContext context, String item) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text(c.tr('removeFromCartTitle')),
      content: Text(c.tr('removeFromCartBody').replaceAll('{item}', item)),
      actions: [
        TextButton(key: const Key('cancelRemove'), onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
        FilledButton(
          key: const Key('confirmRemove'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, minimumSize: const Size(88, 40)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(c.tr('remove')),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// [base] plus room under the last item for the floating navigation, which the
/// page scrolls under (the shell sets extendBody, so the nav's height arrives
/// as bottom padding in MediaQuery; outside the shell it is just the safe area).
EdgeInsets clearNav(BuildContext context, EdgeInsets base) => base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);

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

/// Asks before deleting. Returns true when the user confirms.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${c.tr('delete')}: $what'),
      content: Text(c.tr('confirmDelete')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
        FilledButton(
          key: const Key('confirmDelete'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, minimumSize: const Size(88, 40)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(c.tr('delete')),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Phone input limited to a 10-digit Saudi mobile number (05XXXXXXXX).
final List<TextInputFormatter> phoneInputFormatters = [SaudiPhoneInputFormatter()];

/// Keeps a phone field to the local form 05XXXXXXXX (10 digits), but turns a
/// typed or pasted international number (+966…, 00966…, 966…) into that form
/// first instead of cutting it off (QA BUG-7). Eastern Arabic digits become
/// Western ones.
class SaudiPhoneInputFormatter extends TextInputFormatter {
  static const _eastern = '٠١٢٣٤٥٦٧٨٩';

  static String format(String input) {
    final b = StringBuffer();
    for (final ch in input.split('')) {
      final e = _eastern.indexOf(ch);
      if (e >= 0) {
        b.write(e);
      } else if (RegExp('[0-9]').hasMatch(ch)) {
        b.write(ch);
      }
    }
    var d = b.toString();
    if (d.startsWith('00966')) {
      d = '0${d.substring(5)}';
    } else if (d.startsWith('966') && d.length > 3) {
      d = '0${d.substring(3)}';
    }
    return d.length > 10 ? d.substring(0, 10) : d;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = format(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
