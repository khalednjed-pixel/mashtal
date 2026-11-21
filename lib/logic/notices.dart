import '../models/models.dart';

/// What a reservation notice says (US-19).
enum NoticeKind { accepted, rejected, expiringSoon, expired }

/// An in-app notification about one of the customer's reservations.
class ReservationNotice {
  const ReservationNotice({required this.reservation, required this.kind, required this.at});
  final Reservation reservation;
  final NoticeKind kind;

  /// When it happened, which orders the list.
  final DateTime at;

  /// Stable, so "seen" survives restarts.
  String get id => '${reservation.id}:${kind.name}';
}

/// The reminder comes this long before the hold ends (US-19 AC-02).
const remindBefore = Duration(hours: 6);

/// Notices for [mine] (the customer's reservations) at [now], newest first.
///
/// Push needs Cloud Functions (paid plan), so notices are worked out on the
/// device from the reservation itself: accepted and rejected from the
/// nursery's answer, and the reminder and expiry from acceptedAt + 48 hours.
List<ReservationNotice> reservationNotices(Iterable<Reservation> mine, DateTime now) {
  final out = <ReservationNotice>[];
  for (final r in mine) {
    switch (r.status) {
      case ReservationStatus.rejected:
        out.add(ReservationNotice(reservation: r, kind: NoticeKind.rejected, at: r.rejectedAt ?? r.createdAt));
      case ReservationStatus.accepted || ReservationStatus.pickedUp:
        final accepted = r.acceptedAt;
        if (accepted == null) continue;
        out.add(ReservationNotice(reservation: r, kind: NoticeKind.accepted, at: accepted));
        if (r.status == ReservationStatus.pickedUp) continue;
        final ends = r.expiresAt!;
        final remind = ends.subtract(remindBefore);
        // Once the hold has ended, the expiry replaces the reminder.
        if (!now.isBefore(ends)) {
          out.add(ReservationNotice(reservation: r, kind: NoticeKind.expired, at: ends));
        } else if (!now.isBefore(remind)) {
          out.add(ReservationNotice(reservation: r, kind: NoticeKind.expiringSoon, at: remind));
        }
      case ReservationStatus.pending:
        continue;
    }
  }
  return out..sort((a, b) => b.at.compareTo(a.at));
}
