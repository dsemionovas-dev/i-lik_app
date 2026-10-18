import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../application/report_service.dart';
import '../domain/content_report.dart';

/// Supaprastinta pranešimo apie klaidą forma. Kontekstas (pamoka, užduotis,
/// gido kortelė) pridedamas automatiškai – vartotojui jo nereikia aprašyti.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.lessonId, this.itemId, this.guideCardId});

  final String? lessonId;
  final String? itemId;
  final String? guideCardId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _message = TextEditingController();
  late var _category = widget.lessonId != null || widget.guideCardId != null
      ? ReportCategory.contentError
      : ReportCategory.appBug;
  String? _error;
  var _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String? get _contextLabel => switch ((widget.lessonId, widget.itemId, widget.guideCardId)) {
        (final lesson?, final item?, _) => 'Pamoka $lesson, užduotis $item',
        (final lesson?, null, _) => 'Pamoka $lesson',
        (null, _, final card?) => 'Gido atmintinė $card',
        _ => null,
      };

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final delivery = await ref.read(reportServiceProvider).submit(
            category: _category,
            message: _message.text,
            lessonId: widget.lessonId,
            itemId: widget.itemId,
            guideCardId: widget.guideCardId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (delivery) {
          ReportDelivery.sent => 'Ačiū! Pranešimas išsiųstas.',
          ReportDelivery.queued => 'Ačiū! Pranešimas išsaugotas ir bus išsiųstas, kai atsiras ryšys.',
          ReportDelivery.localOnly => 'Ačiū! Pranešimas išsaugotas įrenginyje.',
        }),
      ));
      context.canPop() ? context.pop() : context.go(Routes.home);
    } on ReportValidationError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contextLabel = _contextLabel;
    return Scaffold(
      appBar: AppBar(title: const Text('Pranešti apie klaidą')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (contextLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Chip(
                key: const ValueKey('report-context'),
                avatar: const Icon(Icons.link, size: 18),
                label: Text(contextLabel),
              ),
            ),
          RadioGroup<ReportCategory>(
            groupValue: _category,
            onChanged: (c) => setState(() => _category = c!),
            child: Column(
              children: [
                for (final c in ReportCategory.values)
                  RadioListTile<ReportCategory>(
                    key: ValueKey('report-category-${c.key}'),
                    value: c,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.label),
                    subtitle: Text(c.hint),
                  ),
              ],
            ),
          ),
          if (_category == ReportCategory.unsafeAdvice)
            Text(
              'Ačiū – tokie pranešimai peržiūrimi pirmiausia.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('report-message'),
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: ContentReport.maxLength,
            decoration: const InputDecoration(
              labelText: 'Kas negerai?',
              hintText: 'Pvz.: 3 klausime teisingas atsakymas turėtų būti 90°, ne 180°.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          Text(
            'Nenurodykite asmeninės informacijos. Kartu siunčiama programėlės versija ir platforma.',
            style: theme.textTheme.bodySmall,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, key: const ValueKey('report-error'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: const Text('Siųsti'),
          ),
        ],
      ),
    );
  }
}
