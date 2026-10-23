import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories.dart';
import '../../data/seed/seed_data.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Phone number and one-time code sign-in (US-02).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Where to return after sign-in (US-01 AC-02).
  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  OtpRequest? _request;
  String? _error;
  bool _busy = false;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthRepository get _auth => context.read<AppState>().backend;

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await _auth.sendCode(_phone.text);
      _code.clear();
      setState(() => _request = request);
      _startCountdown(AuthRepository.resendDelay);
    } on AuthException catch (e) {
      setState(() => _error = context.tr('err.${e.code}'));
      if (e.retryAfter != null) _startCountdown(e.retryAfter!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown(Duration d) {
    _timer?.cancel();
    setState(() => _secondsLeft = d.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _auth.verifyCode(_request!.phone, _code.text);
      if (!mounted) return;
      switch (result) {
        case SignedIn():
          // The router sends the user back to `from` once the session starts.
          break;
        case NeedsProfile(:final phone):
          context.go(Uri(path: '/login/profile', queryParameters: {
            'phone': phone,
            if (widget.from != null) 'from': widget.from!,
          }).toString());
      }
    } on AuthException catch (e) {
      setState(() => _error = context.tr('err.${e.code}'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = _request;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/shop')),
        actions: const [LanguageButton()],
      ),
      body: Constrained(
        maxWidth: 480,
        child: SelectionArea(child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(context.tr('appName'), style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(context.tr('tagline'), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (widget.from != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(context.tr('signInToContinue')),
                  subtitle: Text(context.tr('signInReason')),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (request == null) ..._phoneStep(context) else ..._codeStep(context, request),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('authError'), style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 32),
            _DemoAccounts(onPick: (phone) {
              setState(() {
                _phone.text = phone;
                _request = null;
                _error = null;
              });
            }),
          ],
        )),
      ),
    );
  }

  List<Widget> _phoneStep(BuildContext context) => [
        TextField(
          key: const Key('phoneField'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          inputFormatters: phoneInputFormatters,
          maxLength: 10,
          decoration: InputDecoration(labelText: context.tr('phoneNumber'), hintText: context.tr('phoneHint'), prefixIcon: const Icon(Icons.phone_iphone)),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('sendCode'),
          onPressed: _busy || _secondsLeft > 0 ? null : _sendCode,
          child: Text(_secondsLeft > 0 ? '${context.tr('resendIn')} $_secondsLeft ${context.tr('seconds')}' : context.tr('sendCode')),
        ),
      ];

  List<Widget> _codeStep(BuildContext context, OtpRequest request) {
    final theme = Theme.of(context);
    return [
      Text('${context.tr('codeSentTo')} ${request.phone}', textDirection: null),
      if (request.demoCode != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.sms_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text('${context.tr('demoSms')} ${request.demoCode}', key: const Key('demoCode'))),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        key: const Key('codeField'),
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        decoration: InputDecoration(labelText: context.tr('enterCode')),
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: 16),
      FilledButton(key: const Key('verify'), onPressed: _busy ? null : _verify, child: Text(context.tr('verify'))),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _request = null;
              _error = null;
            }),
            child: Text(context.tr('changeNumber')),
          ),
          TextButton(
            key: const Key('resend'),
            onPressed: _busy || _secondsLeft > 0 ? null : _sendCode,
            child: Text(_secondsLeft > 0 ? '${context.tr('resendIn')} $_secondsLeft ${context.tr('seconds')}' : context.tr('resend')),
          ),
        ],
      ),
    ];
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(context.tr('demoAccounts'), style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(context.tr('demoAccountsHint'), style: theme.textTheme.bodySmall),
            ),
            for (final u in seedUsers)
              ListTile(
                dense: true,
                title: Text(u.name),
                subtitle: Text(roleLabel(context.lang, u.role)),
                trailing: Text(u.phone, textDirection: TextDirection.ltr),
                onTap: () => onPick(u.phone),
              ),
          ],
        ),
      ),
    );
  }
}
