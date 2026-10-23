import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local_backend.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await LocalBackend.open();
  final app = await AppState.create(backend);
  runApp(ChangeNotifierProvider.value(value: app, child: const MashtalApp()));
}
