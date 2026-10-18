import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../application/auth_controller.dart';

enum _Step { email, code, newPasswordOnly, done }

/// „Pamiršau slaptažodį“: el. paštas → 6 skaitmenų kodas iš laiško + naujas slaptažodis.
/// [newPasswordOnly] – atidaryta laiško nuoroda (vartotojas jau prisijungęs).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail, this.newPasswordOnly = false});

  final String? initialEmail;
  final bool newPasswordOnly;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late var _step = widget.newPasswordOnly ? _Step.newPasswordOnly : _Step.email;

  @override
  void initState() {
    super.initState();
    // Ankstesnio veiksmo (pvz., prisijungimo klaidos) pranešimas čia nerodomas.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(authControllerProvider));
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthController get _controller => ref.read(authControllerProvider.notifier);

  Future<void> _sendCode() async {
    if (await _controller.requestPasswordReset(_email.text)) setState(() => _step = _Step.code);
  }

  Future<void> _reset() async {
    final ok = await _controller.resetPassword(
      email: _email.text,
      code: _code.text,
      password: _password.text,
      confirmation: _confirmation.text,
    );
    if (ok) setState(() => _step = _Step.done);
  }

  Future<void> _setNewPassword() async {
    if (await _controller.setPassword(_password.text, _confirmation.text)) setState(() => _step = _Step.done);
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.profile);

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authControllerProvider);
    final busy = action.isLoading;
    final theme = Theme.of(context);

    Widget passwordFields() => Column(
          spacing: 12,
          children: [
            TextField(
              key: const ValueKey('reset-password-field'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Naujas slaptažodis',
                helperText: 'Bent 8 simboliai, raidės ir skaičiai',
              ),
            ),
            TextField(
              key: const ValueKey('reset-confirm-field'),
              controller: _confirmation,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Pakartokite slaptažodį'),
            ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Slaptažodžio atstatymas')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ...switch (_step) {
            _Step.email => [
                const Text('Įveskite paskyros el. paštą – atsiųsime laišką su 6 skaitmenų kodu.'),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('reset-email-field'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'El. paštas'),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: busy ? null : _sendCode, child: const Text('Siųsti kodą')),
              ],
            _Step.code => [
                Text('Kodas išsiųstas adresu ${_email.text.trim()} (jei tokia paskyra yra). '
                    'Laiškas gali užtrukti kelias minutes – patikrinkite ir šlamšto aplanką.'),
                const SizedBox(height: 8),
                Text(
                  'Prisijungus atkurta paskyra pakeis svečio režimą šiame įrenginyje.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('reset-code-field'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Kodas iš laiško'),
                ),
                passwordFields(),
                const SizedBox(height: 24),
                FilledButton(onPressed: busy ? null : _reset, child: const Text('Keisti slaptažodį')),
                TextButton(
                  onPressed: busy ? null : () => setState(() => _step = _Step.email),
                  child: const Text('Negavau laiško – siųsti dar kartą'),
                ),
              ],
            _Step.newPasswordOnly => [
                const Text('Sukurkite naują slaptažodį.'),
                const SizedBox(height: 16),
                passwordFields(),
                const SizedBox(height: 24),
                FilledButton(onPressed: busy ? null : _setNewPassword, child: const Text('Išsaugoti')),
              ],
            _Step.done => [
                Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Slaptažodis pakeistas – esate prisijungę.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: _close, child: const Text('Grįžti')),
              ],
          },
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (_step != _Step.done)
            if (action case AsyncError(:final error))
              Text('$error', key: const ValueKey('reset-error'), style: TextStyle(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
