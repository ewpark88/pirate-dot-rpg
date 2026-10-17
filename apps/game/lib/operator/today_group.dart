import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 운영자 '오늘 새 기능'(설계서 6.10, S1 2026-10-17): 사용자가 폰에서 새 기능을 바로 불러 본다.
/// 피버 곧 시작(게이지 99% — 다음 처치에 켜짐) · 보스 브레이크 가득 · 특성 보스 골라 소환 · 연쇄 번개 선원(pelly 전설) 시험 ·
/// 출항 대기 상태 · 첫 10연 다시 받기. 상태를 바꾸는 것은 운영자 명령(OpLoadState 등)만 — 세이브 백업은 위 '저장' 묶음.
class TodayGroup extends ConsumerStatefulWidget {
  const TodayGroup({super.key});

  @override
  ConsumerState<TodayGroup> createState() => _TodayGroupState();
}

class _TodayGroupState extends ConsumerState<TodayGroup> {
  String? _boss;

  void _send(Command c) => ref.read(commandSinkProvider).send(c);

  /// 지금 상태를 고쳐 다시 불러온다.
  void _load(GameState Function(GameState s) edit) => _send(OpLoadState(edit(ref.read(gameStateProvider))));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    // 모든 보스(해역 보스 + 순환 보통 보스 23종) — 특징(특성·패턴·분열)이 있는 보스가 위로. 항목마다 특징 아이콘·이름.
    final bosses = [...t.regions.bosses.values]..sort((a, b) => _features(b).length.compareTo(_features(a).length));
    final legend = t.rarities.rarities.firstWhere((r) => r.id == 'legend').levelMin;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonal(
          key: const Key('op.today.fever'),
          onPressed: () => _load((s) => s.copyWith(progress: s.progress.copyWith(fever: 0.99))),
          child: Text(l10n.opTodayFever),
        ),
        FilledButton.tonal(
          key: const Key('op.today.break'),
          onPressed: () => _send(const OpBossBreak()),
          child: Text(l10n.opTodayBreak),
        ),
        // 좁은 폰에서도 넘치지 않게 폭을 정하고, 항목은 이름(줄임) + 특징 아이콘만 — 특징 이름은 고른 뒤 아래 줄에.
        SizedBox(
          width: 260,
          child: DropdownButton<String>(
            key: const Key('op.today.bossPick'),
            isExpanded: true,
            value: _boss,
            hint: Text(l10n.opTodayBossPick),
            items: [
              for (final b in bosses)
                DropdownMenuItem(
                  value: b.id,
                  child: Row(
                    children: [
                      Flexible(child: Text(tableText(l10n, b.nameKey), overflow: TextOverflow.ellipsis)),
                      for (final f in _features(b)) ...[const SizedBox(width: 4), Icon(_icons[f], size: 16)],
                    ],
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _boss = id),
          ),
        ),
        if (_boss case final id?)
          Wrap(
            key: const Key('op.today.bossTraits'),
            spacing: 6,
            children: [
              for (final f in _features(t.regions.bosses[id]!))
                Chip(
                  avatar: Icon(_icons[f], size: 16),
                  label: Text(_featureName(l10n, f)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        FilledButton.tonal(
          key: const Key('op.today.boss'),
          onPressed: _boss == null ? null : () => _send(OpSpawnBoss(bossId: _boss)),
          child: Text(l10n.opTodayBoss),
        ),
        FilledButton.tonal(
          key: const Key('op.today.arc'),
          onPressed: () {
            _send(OpSetCrew('pelly', level: legend));
            _send(const OpSetFleet(['pelly']));
          },
          child: Text(l10n.opTodayArc),
        ),
        FilledButton.tonal(
          key: const Key('op.today.sail'),
          onPressed: () => _load(
            (s) => s.copyWith(
              progress: s.progress.copyWith(rebirths: s.progress.rebirths < 1 ? 1 : null, sailHold: true),
            ),
          ),
          child: Text(l10n.opTodaySail),
        ),
        FilledButton.tonal(
          key: const Key('op.today.firstTen'),
          onPressed: () => _load((s) => s.copyWith(summonsTotal: 0)),
          child: Text(l10n.opTodayFirstTen),
        ),
      ],
    );
  }
}

/// 보스 특징: 특성(BossDef.traits — evade·armor·regen·reflect·enrage·escort·dash) + 패턴(mechanic·patterns) + 분열.
List<String> _features(BossDef b) => [
  for (final tr in b.traits) tr.type,
  if (b.mechanic != null || b.patterns.isNotEmpty) 'pattern',
  if (b.splitAt.isNotEmpty) 'split',
];

const Map<String, IconData> _icons = {
  'evade': Icons.air,
  'armor': Icons.shield,
  'regen': Icons.healing,
  'reflect': Icons.flip,
  'enrage': Icons.local_fire_department,
  'escort': Icons.groups,
  'dash': Icons.double_arrow,
  'pattern': Icons.auto_awesome,
  'split': Icons.call_split,
};

String _featureName(AppLocalizations l10n, String f) => switch (f) {
  'evade' => l10n.opTraitEvade,
  'armor' => l10n.opTraitArmor,
  'regen' => l10n.opTraitRegen,
  'reflect' => l10n.opTraitReflect,
  'enrage' => l10n.opTraitEnrage,
  'escort' => l10n.opTraitEscort,
  'dash' => l10n.opTraitDash,
  'split' => l10n.opTraitSplit,
  _ => l10n.opTraitPattern,
};
