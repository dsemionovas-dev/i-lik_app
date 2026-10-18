import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lesson/presentation/widgets/answer_colors.dart';
import '../data/league_repository.dart';
import '../domain/league.dart';

/// „Liko 3 d. 4 val.“ – iki savaitės pabaigos.
String formatTimeLeft(Duration left) {
  if (left.isNegative || left == Duration.zero) return 'Savaitė baigiasi';
  final days = left.inDays, hours = left.inHours % 24, minutes = left.inMinutes % 60;
  if (days > 0) return 'Liko $days d. $hours val.';
  if (hours > 0) return 'Liko $hours val. $minutes min.';
  return 'Liko ${minutes < 1 ? 1 : minutes} min.';
}

class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key, this.now});

  /// Testams; pagal nutylėjimą – dabartinis laikas.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(leagueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lyga')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(leagueProvider.future),
        child: switch (league) {
          AsyncData(value: final standing?) => _LeagueBody(standing: standing, now: (now ?? DateTime.now)()),
          // ListView – kad veiktų „patraukti žemyn“.
          AsyncData() => ListView(
            children: const [_Message(icon: Icons.cloud_off, text: 'Lygos veikia tik prisijungus prie serverio.')],
          ),
          AsyncError() => ListView(
            children: const [
              _Message(
                icon: Icons.wifi_off,
                text: 'Nepavyko įkelti lygos. Patikrinkite ryšį ir patraukite žemyn, kad bandytumėte dar kartą.',
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _LeagueBody extends StatelessWidget {
  const _LeagueBody({required this.standing, required this.now});

  final LeagueStanding standing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = standing;
    final promotionEnd = s.members.lastIndexWhere((m) => s.zoneOf(m.rank) == LeagueZone.promotion);
    final demotionStart = s.members.indexWhere((m) => s.zoneOf(m.rank) == LeagueZone.demotion);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          leading: CircleAvatar(child: Text('${s.tier}')),
          title: Text('${s.tierName} lyga', style: theme.textTheme.titleLarge),
          subtitle: Text('${s.tier} iš ${s.maxTier} · ${formatTimeLeft(s.weekEnd.difference(now))}'),
        ),
        if (s.lastWeek case final last?) _LastWeekBanner(last: last, currentTierName: s.tierName),
        if (!s.joined)
          const _Message(
            icon: Icons.emoji_events_outlined,
            text: 'Užbaik pamoką, kad prisijungtum prie šios savaitės lygos.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Top ${s.promoteCount} kyla į aukštesnę lygą, paskutiniai ${s.demoteCount} – krenta.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final (i, member) in s.members.indexed) ...[
            if (i == demotionStart) _ZoneDivider(label: 'Kritimo zona', color: theme.incorrectColor, up: false),
            _MemberTile(member: member, zone: s.zoneOf(member.rank)),
            if (i == promotionEnd && i < s.members.length - 1)
              _ZoneDivider(label: 'Kilimo zona', color: theme.correctColor, up: true),
          ],
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.zone});

  final LeagueMember member;
  final LeagueZone zone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zoneColor = switch (zone) {
      LeagueZone.promotion => theme.correctColor,
      LeagueZone.demotion => theme.incorrectColor,
      LeagueZone.safe => theme.colorScheme.onSurfaceVariant,
    };
    return Semantics(
      label: '${member.rank} vieta, ${member.isMe ? 'tu' : member.displayName}, ${member.weeklyXp} XP',
      excludeSemantics: true,
      child: Container(
        key: member.isMe ? const ValueKey('league-me') : null,
        color: member.isMe ? theme.colorScheme.primaryContainer : null,
        child: ListTile(
          leading: SizedBox(
            width: 32,
            child: Text(
              '${member.rank}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: zoneColor, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            member.isMe ? 'Tu' : member.displayName,
            style: member.isMe ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
          trailing: Text('${member.weeklyXp} XP', style: theme.textTheme.titleSmall),
        ),
      ),
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider({required this.label, required this.color, required this.up});

  final String label;
  final Color color;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        spacing: 8,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: color),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}

class _LastWeekBanner extends StatelessWidget {
  const _LastWeekBanner({required this.last, required this.currentTierName});

  final LeagueLastWeek last;
  final String currentTierName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, text) = switch (last.outcome) {
      LeagueOutcome.promoted => (
        Icons.trending_up,
        theme.correctColor,
        'Praėjusią savaitę – ${last.finalRank} vieta. Pakilai į „$currentTierName“ lygą!',
      ),
      LeagueOutcome.demoted => (
        Icons.trending_down,
        theme.incorrectColor,
        'Praėjusią savaitę – ${last.finalRank} vieta. Nukritai į „$currentTierName“ lygą.',
      ),
      LeagueOutcome.stayed => (
        Icons.trending_flat,
        theme.colorScheme.onSurfaceVariant,
        'Praėjusią savaitę – ${last.finalRank} vieta. Lieki „$currentTierName“ lygoje.',
      ),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(icon, color: color),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        spacing: 12,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
