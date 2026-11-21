import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/notices.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Title and body of a reservation notice in the current language.
(String, String) noticeText(BuildContext context, ReservationNotice n) {
  final app = context.read<AppState>();
  final lang = context.lang;
  final r = n.reservation;
  final nursery = app.backend.nurseryById(r.nurseryId)?.name(lang) ?? '';
  final when = DateFormat('d MMM, HH:mm', lang);
  String t(String key) => context.tr(key).replaceAll('{nursery}', nursery);
  return switch (n.kind) {
    NoticeKind.accepted => (t('n.accepted'), t('n.acceptedBody').replaceAll('{time}', when.format(r.expiresAt!.toLocal()))),
    NoticeKind.rejected => (
        t('n.rejected'),
        r.rejectReason == null ? '' : '${context.tr('rejectReason')}: ${context.tr('reason.${r.rejectReason!.name}')}',
      ),
    NoticeKind.expiringSoon => (t('n.expiringSoon'), t('n.expiringSoonBody').replaceAll('{time}', when.format(r.expiresAt!.toLocal()))),
    NoticeKind.expired => (t('n.expired'), t('n.expiredBody')),
  };
}

IconData noticeIcon(NoticeKind k) => switch (k) {
      NoticeKind.accepted => Icons.event_available,
      NoticeKind.rejected => Icons.event_busy,
      NoticeKind.expiringSoon => Icons.hourglass_bottom,
      NoticeKind.expired => Icons.timer_off_outlined,
    };

/// The customer's reservation notices (US-19), unseen ones marked. Opening
/// the screen marks them all seen.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Unseen when the screen opened, so they stay marked while it is open.
  Set<String>? _fresh;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final notices = app.noticesAt(now);
    _fresh ??= {for (final n in notices) if (!app.isSeen(n)) n.id};
    if (notices.any((n) => !app.isSeen(n))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) app.markSeen(notices);
      });
    }
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notifications')), actions: const [LanguageButton()]),
      body: notices.isEmpty
          ? EmptyState(icon: Icons.notifications_none, title: context.tr('noNotifications'), body: context.tr('noNotificationsBody'))
          : Constrained(
              child: ListView(
                padding: clearNav(context, const EdgeInsets.all(MashtalSpace.screen)),
                children: [
                  for (final n in notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MashtalSpace.sm),
                      child: _NoticeTile(notice: n, fresh: _fresh!.contains(n.id), now: now, text: text),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.fresh, required this.now, required this.text});
  final ReservationNotice notice;
  final bool fresh;
  final DateTime now;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final (title, body) = noticeText(context, notice);
    final bad = notice.kind == NoticeKind.rejected || notice.kind == NoticeKind.expired;
    return Card(
      key: Key('notice-${notice.id}'),
      color: fresh ? MashtalColors.ground : null,
      child: InkWell(
        onTap: () => context.go('/reservations'),
        child: Padding(
          padding: const EdgeInsets.all(MashtalSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bad ? MashtalColors.errorSoft : MashtalColors.mint, shape: BoxShape.circle),
                child: Icon(noticeIcon(notice.kind), size: 20, color: bad ? MashtalColors.error : MashtalColors.forest),
              ),
              const SizedBox(width: MashtalSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    if (body.isNotEmpty) Text(body, style: text.bodyMedium),
                    const SizedBox(height: MashtalSpace.xs),
                    Text(agoText(context, now.difference(notice.at)), style: text.bodySmall),
                  ],
                ),
              ),
              if (fresh)
                Container(
                  key: Key('unseen-${notice.id}'),
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(color: MashtalColors.emerald, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "5 min ago", "3 h ago", "2 days ago", with Arabic number agreement.
String agoText(BuildContext context, Duration d) {
  if (d.inMinutes < 1) return context.tr('justNow');
  final (n, unit) = d.inHours < 1 ? (d.inMinutes, 'min') : d.inDays < 1 ? (d.inHours, 'h') : (d.inDays, 'd');
  if (context.lang != 'ar') return context.tr('ago.$unit').replaceAll('{n}', '$n');
  const forms = {
    // one, two, 3–10, 11 and more
    'min': ('دقيقة', 'دقيقتين', 'دقائق', 'دقيقة'),
    'h': ('ساعة', 'ساعتين', 'ساعات', 'ساعة'),
    'd': ('يوم', 'يومين', 'أيام', 'يوماً'),
  };
  final (one, two, few, many) = forms[unit]!;
  return switch (n) {
    1 => 'قبل $one',
    2 => 'قبل $two',
    <= 10 => 'قبل $n $few',
    _ => 'قبل $n $many',
  };
}
