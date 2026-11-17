import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/firebase_services.dart';
import 'data/local_backend.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';

/// `--dart-define=MASHTAL_OFFLINE=true` runs on the on-device demo data.
const _offline = bool.fromEnvironment('MASHTAL_OFFLINE');

/// `--dart-define=USE_FIREBASE_EMULATOR=true` talks to the local Firebase
/// emulators (project demo-mashtal) instead of the real project.
const _emulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await _openBackend();
  final app = await AppState.create(backend);
  runApp(ChangeNotifierProvider.value(value: app, child: const MashtalApp()));
}

Future<LocalBackend> _openBackend() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (_offline || options == null) return LocalBackend.open();

  await Firebase.initializeApp(options: _emulator ? options.copyWith(projectId: 'demo-mashtal') : options);
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  if (_emulator) {
    await auth.useAuthEmulator('localhost', 9099);
    db.useFirestoreEmulator('localhost', 8080);
  }
  final services = FirebaseServices(auth, db);
  return LocalBackend.open(accounts: services, remote: services);
}
