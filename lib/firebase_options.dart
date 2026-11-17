import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase settings for the mashtal-1 project (TF-03).
///
/// These values identify the project; they are not secrets. Platforms
/// without settings here run on the offline demo data.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    return null;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBAarO294EdIfB7Y_R8U5OjBUZFtGPrLRE',
    authDomain: 'mashtal-1.firebaseapp.com',
    projectId: 'mashtal-1',
    storageBucket: 'mashtal-1.firebasestorage.app',
    messagingSenderId: '413616395035',
    appId: '1:413616395035:web:55ccc533d5b54ac1edb9be',
  );
}
