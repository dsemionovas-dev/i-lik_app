import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_Credentials>(
      context: context,
      builder: (_) => const _CredentialsDialog(
        title: 'Prisijungti',
        askPassword: true,
        warning: 'Svečio progresas į esamą paskyrą neperkeliamas.',
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
  const _CredentialsDialog({required this.title, required this.askPassword, this.warning});

  final String title;
  final bool askPassword;
  final String? warning;

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
