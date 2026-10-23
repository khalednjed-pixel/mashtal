import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Name and city for a new account (US-02 AC-01).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.phone, this.from});

  final String phone;
  final String? from;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _city = 'riyadh';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().backend.completeProfile(phone: widget.phone, name: _name.text, city: _city);
      // Signed in: send the user back to where they started.
      if (mounted) context.go(widget.from ?? '/');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('err.${e.code}'))));
      context.go('/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('completeProfile')), actions: const [LanguageButton()]),
        body: Constrained(
          maxWidth: 480,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.phone, textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('nameField'),
                  controller: _name,
                  decoration: InputDecoration(labelText: context.tr('name')),
                  validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('nameRequired') : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: InputDecoration(labelText: context.tr('city')),
                  items: [for (final c in cityIds) DropdownMenuItem(value: c, child: Text(context.trCity(c)))],
                  onChanged: (v) => setState(() => _city = v ?? _city),
                ),
                const SizedBox(height: 24),
                FilledButton(key: const Key('createAccount'), onPressed: _busy ? null : _submit, child: Text(context.tr('create'))),
              ],
            ),
          ),
        ),
      );
}
