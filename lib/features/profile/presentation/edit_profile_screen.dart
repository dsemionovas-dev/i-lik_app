import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../application/profile_controller.dart';
import '../domain/profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  TextEditingController? _name;
  String _avatar = defaultAvatar;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileControllerProvider.notifier).save(displayName: _name!.text, avatar: _avatar);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profilis išsaugotas.')));
      context.canPop() ? context.pop() : context.go(Routes.profile);
    } on ProfileFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider).value;
    if (state != null && _name == null) {
      _name = TextEditingController(text: state.displayName == 'Svečias' ? '' : state.displayName);
      _avatar = state.profile.avatar ?? defaultAvatar;
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profilis')),
      body: _name == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Text(avatars[_avatar]!.emoji, style: const TextStyle(fontSize: 64))),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('display-name-field'),
                  controller: _name,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Vardas',
                    helperText: 'Matomas lygoje kitiems. Nenaudokite tikro vardo ir pavardės ar el. pašto.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Avataras', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: key, value: a) in avatars.entries)
                      Semantics(
                        label: a.label,
                        selected: key == _avatar,
                        button: true,
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('avatar-$key'),
                          borderRadius: BorderRadius.circular(32),
                          onTap: () => setState(() => _avatar = key),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: key == _avatar
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            child: Text(a.emoji, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: const ValueKey('profile-error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                FilledButton(onPressed: _saving ? null : _save, child: const Text('Išsaugoti')),
              ],
            ),
    );
  }
}
