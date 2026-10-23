import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/phone.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'partner_form_fields.dart';

class ProfessionalFormScreen extends StatefulWidget {
  const ProfessionalFormScreen({super.key});

  @override
  State<ProfessionalFormScreen> createState() => _ProfessionalFormScreenState();
}

class _ProfessionalFormScreenState extends State<ProfessionalFormScreen> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _phone = TextEditingController();
  final Set<String> _cities = {'riyadh'};
  final Set<ServiceType> _services = {};
  bool _showErrors = false;

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (!_form.currentState!.validate() || _services.isEmpty || _cities.isEmpty) return;
    await context.read<AppState>().backend.createProfessional(Professional(
          id: '',
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim(),
          cities: [for (final c in cityIds) if (_cities.contains(c)) c],
          services: _services,
          phone: SaudiPhone.normalize(_phone.text)!,
          status: PartnerStatus.pending,
        ));
    if (mounted) context.go('/admin/professionals');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('addProfessional'))),
      body: Constrained(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const PendingNote(),
              const SizedBox(height: 16),
              TextFormField(controller: _nameAr, decoration: InputDecoration(labelText: context.tr('nameAr')), validator: (v) => requiredField(context, v)),
              const SizedBox(height: 12),
              TextFormField(controller: _nameEn, decoration: InputDecoration(labelText: context.tr('nameEn')), validator: (v) => requiredField(context, v)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: context.tr('phoneNumber'), hintText: '05XXXXXXXX'),
                validator: (v) => phoneField(context, v),
              ),
              const SizedBox(height: 16),
              Text(context.tr('services'), style: theme.textTheme.titleSmall),
              Wrap(spacing: 8, children: [
                for (final s in ServiceType.values)
                  FilterChip(
                    label: Text(context.trEnum(s)),
                    selected: _services.contains(s),
                    onSelected: (on) => setState(() => on ? _services.add(s) : _services.remove(s)),
                  ),
              ]),
              if (_showErrors && _services.isEmpty) Text(context.tr('required'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              Text(context.tr('city'), style: theme.textTheme.titleSmall),
              Wrap(spacing: 8, children: [
                for (final c in cityIds)
                  FilterChip(
                    label: Text(context.trCity(c)),
                    selected: _cities.contains(c),
                    onSelected: (on) => setState(() => on ? _cities.add(c) : _cities.remove(c)),
                  ),
              ]),
              if (_showErrors && _cities.isEmpty) Text(context.tr('required'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: Text(context.tr('save'))),
            ],
          ),
        ),
      ),
    );
  }
}
