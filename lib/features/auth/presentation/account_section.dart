import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';

import '../../progress/application/progress_controller.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Paskyros būsena profilyje: svečias → susieti el. paštą / prisijungti; paskyra → atsijungti.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final action = ref.watch(authControllerProvider);
    final supportsAccounts = ref.watch(authRepositoryProvider).supportsAccounts;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text('Paskyra', style: theme.textTheme.titleMedium),
            ...switch (user) {
              null => [
                  const Text('Neprisijungta.'),
                  if (supportsAccounts)
                    OutlinedButton(
                      onPressed: () => _signIn(context, ref),
                      child: const Text('Prisijungti'),
                    ),
                ],
              AppUser(isAnonymous: true, :final pendingEmail?) => [
                  const Text('Svečio režimas'),
                  Text(
                    'Laukiama patvirtinimo: $pendingEmail. Atidarykite laišką ir paspauskite nuorodą, '
                    'tada grįžkite į programėlę.',
                    style: theme.textTheme.bodySmall,
                  ),
                  OutlinedButton(
                    onPressed: action.isLoading ? null : () => _linkEmail(context, ref),
                    child: const Text('Siųsti dar kartą / kitas adresas'),
                  ),
                ],
              AppUser(isAnonymous: true) => [
                  const Text('Svečio režimas'),
                  Text(
                    supportsAccounts
                        ? 'Susiekite el. paštą, kad progresas neprapultų pakeitus ar pametus telefoną.'
                        : 'Progresas saugomas tik šiame įrenginyje.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (supportsAccounts) ...[
                    FilledButton(
                      onPressed: action.isLoading ? null : () => _linkEmail(context, ref),
                      child: const Text('Susieti el. paštą'),
                    ),
                    TextButton(
                      onPressed: action.isLoading ? null : () => _signIn(context, ref),
                      child: const Text('Jau turiu paskyrą'),
                    ),
                  ],
                ],
              AppUser(:final email) => [
                  Text(email ?? 'Paskyra', key: const ValueKey('account-email')),
                  if (user.needsPassword) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Nustatykite slaptažodį – be jo kitame telefone prie paskyros neprisijungsite.',
                        style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                      ),
                    ),
                    FilledButton(
                      onPressed: action.isLoading ? null : () => _setPassword(context, ref),
                      child: const Text('Nustatyti slaptažodį'),
                    ),
                  ] else
                    TextButton(
                      onPressed: action.isLoading ? null : () => _setPassword(context, ref),
                      child: const Text('Keisti slaptažodį'),
                    ),
                  OutlinedButton(
                    onPressed: action.isLoading ? null : () => _signOut(context, ref),
                    child: const Text('Atsijungti'),
                  ),
                ],
            },
            if (action.isLoading) const LinearProgressIndicator(),
            if (action case AsyncError(:final error))
              Text('$error', style: TextStyle(color: theme.colorScheme.error)),
            if (action case AsyncData(value: final String message)) Text(message),
          ],
        ),
      ),
    );
  }

  Future<void> _linkEmail(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_Credentials>(
      context: context,
      builder: (_) => const _CredentialsDialog(title: 'Susieti el. paštą', askPassword: false),
    );
    if (input == null) return;
    await ref.read(authControllerProvider.notifier).linkEmail(input.email);
  }

  Future<void> _setPassword(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<({String password, String confirmation})>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (input == null) return;
    await ref.read(authControllerProvider.notifier).setPassword(input.password, input.confirmation);
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_Credentials>(
      context: context,
      builder: (_) => _CredentialsDialog(
        title: 'Prisijungti',
        askPassword: true,
        warning: 'Svečio progresas į esamą paskyrą neperkeliamas.',
        onForgotPassword: (email) => context.push(Routes.resetPassword(email: email.trim())),
      ),
    );
    if (input == null) return;
    await ref.read(authControllerProvider.notifier).signIn(input.email, input.password);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(progressControllerProvider).value?.pending ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atsijungti?'),
        content: Text(pending > 0
            ? 'Dar neišsiųsta bandymų: $pending. Atsijungus jie bus prarasti.'
            : 'Progresas lieka paskyroje – prisijungę jį vėl matysite.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Atšaukti')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Atsijungti')),
        ],
      ),
    );
    if (ok != true) return;
    if (await ref.read(authControllerProvider.notifier).signOut()) {
      await ref.read(progressControllerProvider.notifier).clearLocal();
    }
  }
}

typedef _Credentials = ({String email, String password});

class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({required this.title, required this.askPassword, this.warning, this.onForgotPassword});

  final String title;
  final bool askPassword;
  final String? warning;

  /// Uždaro langą ir atidaro atstatymą (su jau įvestu el. paštu).
  final ValueChanged<String>? onForgotPassword;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (widget.warning != null) Text(widget.warning!, style: Theme.of(context).textTheme.bodySmall),
          TextField(
            key: const ValueKey('email-field'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'El. paštas'),
          ),
          if (widget.askPassword)
            TextField(
              key: const ValueKey('password-field'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Slaptažodis'),
            ),
          if (widget.onForgotPassword != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final email = _email.text;
                  Navigator.pop(context);
                  widget.onForgotPassword!(email);
                },
                child: const Text('Pamiršau slaptažodį?'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Atšaukti')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (email: _email.text, password: _password.text)),
          child: const Text('Tęsti'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Slaptažodis'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text('Bent 8 simboliai, raidės ir skaičiai.', style: Theme.of(context).textTheme.bodySmall),
          TextField(
            key: const ValueKey('new-password-field'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Naujas slaptažodis'),
          ),
          TextField(
            key: const ValueKey('confirm-password-field'),
            controller: _confirmation,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Pakartokite slaptažodį'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Atšaukti')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (password: _password.text, confirmation: _confirmation.text)),
          child: const Text('Išsaugoti'),
        ),
      ],
    );
  }
}
