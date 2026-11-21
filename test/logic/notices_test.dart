import 'package:flutter_test/flutter_test.dart';
import 'package:mashtal/logic/notices.dart';
import 'package:mashtal/models/models.dart';

/// US-19: notices are worked out from the reservation and the clock.
void main() {
  final created = DateTime.utc(2026, 11, 20, 8);
  final accepted = DateTime.utc(2026, 11, 20, 10);
  Reservation res(ReservationStatus status, {DateTime? acceptedAt, DateTime? rejectedAt, RejectReason? reason}) => Reservation(
        id: 'r1',
        customerId: 'u-c1',
        customerName: 'Sara',
        customerPhone: '0500000005',
        nurseryId: 'n1',
        items: const [ReservationItem(listingId: 'l1', plantId: 'p01', quantity: 1, price: 180)],
        createdAt: created,
        status: status,
        acceptedAt: acceptedAt,
        rejectedAt: rejectedAt,
        rejectReason: reason,
      );
  List<NoticeKind> kinds(Reservation r, DateTime now) => [for (final n in reservationNotices([r], now)) n.kind];

  test('a pending reservation has no notice', () {
    expect(kinds(res(ReservationStatus.pending), created), isEmpty);
  });

  test('AC-01 accepted and rejected are notices from the moment they are saved', () {
    final a = reservationNotices([res(ReservationStatus.accepted, acceptedAt: accepted)], accepted);
    expect(a.single.kind, NoticeKind.accepted);
    expect(a.single.at, accepted);
    expect(a.single.id, 'r1:accepted');

    final rejectedAt = accepted.add(const Duration(minutes: 3));
    final r = reservationNotices([res(ReservationStatus.rejected, rejectedAt: rejectedAt, reason: RejectReason.outOfStock)], rejectedAt);
    expect(r.single.kind, NoticeKind.rejected);
    expect(r.single.at, rejectedAt);
  });

  test('AC-02 the reminder comes 6 hours before the 48-hour hold ends', () {
    final r = res(ReservationStatus.accepted, acceptedAt: accepted);
    expect(kinds(r, accepted.add(const Duration(hours: 41, minutes: 59))), [NoticeKind.accepted]);
    expect(kinds(r, accepted.add(const Duration(hours: 42))), [NoticeKind.expiringSoon, NoticeKind.accepted]);
  });

  test('AC-01 at acceptedAt + 48h the reservation has expired, newest first', () {
    final r = res(ReservationStatus.accepted, acceptedAt: accepted);
    final n = reservationNotices([r], accepted.add(const Duration(hours: 48)));
    expect(n.map((e) => e.kind), [NoticeKind.expired, NoticeKind.accepted], reason: 'the expiry replaces the reminder');
    expect(n.first.at, accepted.add(const Duration(hours: 48)));
  });

  test('a picked-up reservation never expires or reminds', () {
    final r = res(ReservationStatus.pickedUp, acceptedAt: accepted);
    expect(kinds(r, accepted.add(const Duration(days: 5))), [NoticeKind.accepted]);
  });
}
