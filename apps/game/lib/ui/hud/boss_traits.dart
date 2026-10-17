import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 보스 특성 UI (docs/specs/economy-boss-traits.md, 사용자 요청 #25): 이름표·컷인에 특성 아이콘 + 한 줄
// ('회피 25% · 투척·집속·원형에 약함'), 약점 칩은 특성의 카운터 계열까지, 편성 고르기에서 카운터 선원 강조.

/// 한 줄에 이름을 보여 줄 카운터 계열 수 (넘치면 자른다 — 칩 쪽엔 전부).
const _summaryCounters = 3;

IconData traitIcon(String type) => switch (type) {
  'evade' => Icons.air_rounded,
  'armor' => Icons.shield_rounded,
  'regen' => Icons.healing_rounded,
  'reflect' => Icons.flip_rounded,
  'enrage' => Icons.local_fire_department_rounded,
  'escort' => Icons.groups_rounded,
  'dash' => Icons.fast_forward_rounded,
  _ => Icons.star_rounded,
};

String _pct(double ratio) => shortDecimal(ratio * 100);

/// 특성 이름 (수치가 있으면 같이): '회피 25%' · '재생 초당 1.5%' · '호위 3'.
String traitName(AppLocalizations l, BossTraitDef t) {
  final c = t.cfg;
  return switch (t.type) {
    'evade' when c.numberOr('areaChance', 0) > 0 => l.uiTraitEvadeArea(_pct(c.number('areaChance'))),
    'evade' => l.uiTraitEvade(_pct(c.numberOr('chance', 0))),
    'armor' => l.uiTraitArmor,
    'regen' => l.uiTraitRegen(_pct(c.numberOr('perSec', 0))),
    'reflect' => l.uiTraitReflect,
    'enrage' => l.uiTraitEnrage,
    'escort' => l.uiTraitEscort(c.numberOr('count', 0).round()),
    _ => l.uiTraitDash,
  };
}

/// 잘 먹히는 계열: 표의 약점(weakFamilies) + 특성 카운터(counterFamilies), 겹치면 한 번.
List<String> bossCounters(BossDef b) => {...b.weakFamilies, ...b.counterFamilies}.toList();

/// 한 줄 요약: '회피 25% · 투척·집속·원형에 약함'. 특성·약점이 없으면 빈 글.
String traitSummary(AppLocalizations l, GameTables t, BossDef b) {
  final counters = b.counterFamilies.take(_summaryCounters).map((f) => tableText(l, t.skills.byId(f).nameKey));
  return [
    for (final tr in b.traits) traitName(l, tr),
    if (counters.isNotEmpty) l.uiTraitWeakTo(counters.join('·')),
  ].join(' · ');
}

/// 특성 아이콘 + 한 줄 (이름표·컷인·항해 탭). 특성이 없으면 그리지 않는다.
class BossTraitLine extends StatelessWidget {
  const BossTraitLine({required this.boss, required this.tables, this.color = Colors.white, this.size = 13, super.key});

  final BossDef boss;
  final GameTables tables;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (boss.traits.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('boss.traits'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in boss.traits) ...[
          Icon(traitIcon(t.type), key: Key('boss.trait.${t.type}'), size: size + 3, color: const Color(0xFFFFD84A)),
          const SizedBox(width: 2),
        ],
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            traitSummary(l10n, tables, boss),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 다음(또는 지금) 보스에게 잘 먹히는 계열 — 편성 고르기에서 카운터 선원을 강조한다. 스테이지가 바뀔 때만 다시.
final bossCounterFamiliesProvider = Provider<Set<String>>((ref) {
  final t = ref.watch(tablesProvider);
  final stage = ref.watch(gameStateProvider.select((s) => s.progress.stage));
  return bossCounters(t.regions.bossAt(stage)).toSet();
});

/// '보스 약점' 작은 칩 (편성 후보 줄).
class CounterChip extends StatelessWidget {
  const CounterChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: const Color(0xFFFFE3E8), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.gps_fixed_rounded, size: 12, color: Color(0xFFC2185B)),
        const SizedBox(width: 3),
        Text(
          AppLocalizations.of(context).uiCounterChip,
          style: const TextStyle(fontSize: 12, color: Color(0xFFC2185B), fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
