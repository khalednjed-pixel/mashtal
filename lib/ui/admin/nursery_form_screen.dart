import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../logic/phone.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'partner_form_fields.dart';

class NurseryFormScreen extends StatefulWidget {
  const NurseryFormScreen({super.key});

  @override
  State<NurseryFormScreen> createState() => _NurseryFormScreenState();
}

class _NurseryFormScreenState extends State<NurseryFormScreen> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _district = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController(text: '8:00–22:00');
  String _city = 'riyadh';

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _district, _phone, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AppState>().backend.createNursery(Nursery(
          id: '',
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim(),
          city: _city,
          district: _district.text.trim(),
          phone: SaudiPhone.normalize(_phone.text)!,
          hours: _hours.text.trim(),
          status: PartnerStatus.pending,
        ));
    if (mounted) context.go('/admin/nurseries');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('addNursery'))),
        body: Constrained(
          maxWidth: 560,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PendingNote(),
                const SizedBox(height: 16),
                TextFormField(key: const Key('nameAr'), controller: _nameAr, decoration: InputDecoration(labelText: context.tr('nameAr')), validator: (v) => requiredField(context, v)),
                const SizedBox(height: 12),
                TextFormField(key: const Key('nameEn'), controller: _nameEn, decoration: InputDecoration(labelText: context.tr('nameEn')), validator: (v) => requiredField(context, v)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: InputDecoration(labelText: context.tr('city')),
                  items: [for (final c in cityIds) DropdownMenuItem(value: c, child: Text(context.trCity(c)))],
                  onChanged: (v) => setState(() => _city = v ?? _city),
                ),
                const SizedBox(height: 12),
                TextFormField(key: const Key('district'), controller: _district, decoration: InputDecoration(labelText: context.tr('district')), validator: (v) => requiredField(context, v)),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('partnerPhone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: context.tr('phoneNumber'), hintText: '05XXXXXXXX'),
                  validator: (v) => phoneField(context, v),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _hours, decoration: InputDecoration(labelText: context.tr('hours'))),
                const SizedBox(height: 24),
                FilledButton(key: const Key('savePartner'), onPressed: _save, child: Text(context.tr('save'))),
              ],
            ),
          ),
        ),
      );
}
