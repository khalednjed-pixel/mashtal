import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'accounts.dart';
import 'remote_store.dart';

/// Firebase versions of [AccountService] and [RemoteStore] (TF-03).
///
/// Sign-in: the app checks the on-screen code itself, then signs in to a
/// Firebase Email/Password account named after the phone number
/// (966500000001@phone.mashtal.app). The user never sees the email or the
/// password. This was chosen so any number can sign in without paid SMS; it
/// means the phone number is not truly verified (anyone who knows the scheme
/// could sign in as any number), which is acceptable for the course demo.
class FirebaseServices implements AccountService, RemoteStore {
  FirebaseServices(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _emailDomain = 'phone.mashtal.app';

  /// '0500000001' → '+966500000001'.
  static String e164(String local) => '+966${local.substring(1)}';
  static String _email(String local) => '${e164(local).substring(1)}@$_emailDomain';
  static String _password(String local) => 'mashtal-${e164(local)}';

  // ------------------------------------------------------------ Accounts

  @override
  Future<AppUser?> restore() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return null;
    try {
      final profile = await loadProfile(user.uid);
      if (profile == null) await _auth.signOut();
      return profile;
    } catch (e) {
      debugPrint('Could not restore the session: $e');
      return null;
    }
  }

  @override
  Future<String> signIn(String phone) async {
    final email = _email(phone);
    final password = _password(phone);
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      // First visit: the account does not exist yet. New projects answer
      // `invalid-credential` instead of `user-not-found`.
      if (e.code != 'user-not-found' && e.code != 'invalid-credential' && e.code != 'INVALID_LOGIN_CREDENTIALS') rethrow;
    }
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return cred.user!.uid;
  }

  @override
  Future<AppUser?> loadProfile(String uid) async {
    final snap = await _db.doc('users/$uid').get();
    final d = snap.data();
    if (d == null) return null;
    return AppUser(
      id: uid,
      phone: _local(d['phone'] as String),
      name: d['name'] as String,
      city: d['city'] as String,
      role: Role.values.byName(d['role'] as String),
      partnerId: d['partnerId'] as String?,
    );
  }

  static String _local(String phone) => phone.startsWith('+966') ? '0${phone.substring(4)}' : phone;

  @override
  Future<PartnerAccount?> partnerAccount(String phone) async {
    final snap = await _db.doc('partnerAccounts/${e164(phone)}').get();
    final d = snap.data();
    if (d == null) return null;
    return PartnerAccount(Role.values.byName(d['role'] as String), d['partnerId'] as String?);
  }

  @override
  Future<void> saveProfile(AppUser user) async {
    final ref = _db.doc('users/${user.id}');
    final existing = await ref.get();
    if (existing.exists) {
      // Only the role can change here, to match partnerAccounts.
      await ref.update({'role': user.role.name, 'partnerId': user.partnerId});
    } else {
      await ref.set({
        'phone': e164(user.phone),
        'name': user.name,
        'city': user.city,
        'role': user.role.name,
        'partnerId': ?user.partnerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> updateProfile(String uid, {required String name, required String city}) =>
      _db.doc('users/$uid').update({'name': name, 'city': city});

  @override
  Future<void> setPartnerAccount(String phone, Role role, String? partnerId) =>
      _db.doc('partnerAccounts/${e164(phone)}').set({'role': role.name, 'partnerId': ?partnerId});

  @override
  Future<void> removePartnerAccount(String phone) => _db.doc('partnerAccounts/${e164(phone)}').delete();

  @override
  Future<void> signOut() => _auth.signOut();

  // ---------------------------------------------------------------- Data

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  @override
  void watch(AppUser? viewer, void Function(String collection, List<Map<String, dynamic>> docs) onData) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    final admin = viewer?.role == Role.admin;
    final partnerId = viewer?.partnerId;
    final verified = PartnerStatus.verified.name;

    // Each collection may need two queries (public part + the viewer's own
    // records); their results are merged by document id.
    void listen(String collection, List<Query<Map<String, dynamic>>> queries) {
      final parts = List<Map<String, Map<String, dynamic>>>.generate(queries.length, (_) => {});
      final seen = List<bool>.filled(queries.length, false);
      for (final (i, q) in queries.indexed) {
        _subs.add(q.snapshots().listen(
          (snap) {
            parts[i] = {for (final d in snap.docs) d.id: {...d.data(), 'id': d.id}};
            seen[i] = true;
            if (!seen.every((s) => s)) return;
            onData(collection, [for (final p in parts) ...p.values].fold<Map<String, Map<String, dynamic>>>(
              {},
              (all, d) => all..[d['id'] as String] = d,
            ).values.toList());
          },
          onError: (Object e) {
            debugPrint('Listening to $collection failed: $e');
            seen[i] = true;
          },
        ));
      }
    }

    final nurseries = _db.collection('nurseries');
    final pros = _db.collection('professionals');
    final listings = _db.collection('listings');

    listen('plants', [_db.collection('plants')]);
    listen('priceRanges', [_db.collection('priceRanges')]);
    listen('nurseries', [
      if (admin) nurseries else nurseries.where('status', isEqualTo: verified),
      if (viewer?.role == Role.nursery && partnerId != null) nurseries.where(FieldPath.documentId, isEqualTo: partnerId),
    ]);
    listen('professionals', [
      if (admin) pros else pros.where('status', isEqualTo: verified),
      if (viewer?.role == Role.professional && partnerId != null) pros.where(FieldPath.documentId, isEqualTo: partnerId),
    ]);
    listen('listings', [
      if (admin) listings else listings.where('public', isEqualTo: true),
      if (viewer?.role == Role.nursery && partnerId != null) listings.where('nurseryId', isEqualTo: partnerId),
    ]);
    if (admin) {
      listen('plantEdits', [_db.collection('plantEdits')]);
      listen('users', [_db.collection('users')]);
    }
  }

  @override
  Future<void> commit(List<RemoteWrite> writes) async {
    // A batch holds at most 500 writes.
    for (var start = 0; start < writes.length; start += 400) {
      final batch = _db.batch();
      for (final w in writes.skip(start).take(400)) {
        final ref = _db.collection(w.collection).doc(w.id);
        final data = w.data;
        if (data == null) {
          batch.delete(ref);
        } else {
          batch.set(ref, data);
        }
      }
      await batch.commit();
    }
  }

  @override
  Future<bool> isSeeded() async => (await _db.doc('meta/seed').get()).exists;

  @override
  Future<void> markSeeded() => _db.doc('meta/seed').set({'at': FieldValue.serverTimestamp()});

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
