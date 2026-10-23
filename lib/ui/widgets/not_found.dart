import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import 'common.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.search_off,
          title: context.tr('notFound'),
          actions: [OutlinedButton(onPressed: () => context.go('/'), child: Text(context.tr('goHome')))],
        ),
      );
}
