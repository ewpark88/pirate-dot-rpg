import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart' show rangeLevel, rangeText;
import 'package:pirate_dot/ui/guide/guide_marks.dart' show guideMotionProvider;
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

// 선원 상세 HD 개편 (S1 2026-10-18): 위쪽 큰 머리판(계열 색 배경 · 등급 색 테 · 숨쉬기) · 능력치 막대(공격력·공격 속도·
// 사거리·특성, 다음 레벨/등급 미리보기는 초록 꼬리) · 등급 사다리(지금 칸 빛남). 숨쉬기는 전장 틱으로(따로 도는 컨트롤러 없음).

/// 계열마다 배경 색(계열 순서로 돌려 쓴다).
const _familyTints = [
  Color(0xFF7FC8F8),
  Color(0xFFF4A261),
  Color(0xFF9BD08A),
  Color(0xFFC3A6F0),
  Color(0xFFF28FA5),
  Color(0xFF6FD3C7),
  Color(0xFFF2D06B),
];

Color familyTint(GameTables t, String family) {
  final i = t.skills.families.indexWhere((f) => f.id == family);
  return _familyTints[(i < 0 ? 0 : i) % _familyTints.length];
}

/// 머리판: 계열 색 하늘 + 등급 색 테 안에 큰 카드(숨쉬기) · 오른쪽에 전체 이름·등급·출전.
class CrewHero extends ConsumerWidget {
  const CrewHero({
    required this.def,
    required this.rarity,
    required this.owned,
    required this.name,
    required this.info,
    super.key,
  });

  final CrewDef def;
  final RarityDef rarity;
  final bool owned;
  final String name;

  /// 오른쪽 글(전체 이름·알약들).
  final Widget info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final edge = rarityColor(rarity);
    final tint = familyTint(t, def.family);
    final calm = MediaQuery.disableAnimationsOf(context) || !ref.watch(guideMotionProvider);
    // 숨쉬기: 전장 틱 2초 주기(전투가 없으면 가만히).
    final phase = calm ? 0 : ref.watch(gameStateProvider.select((s) => (s.battle?.tick ?? 0) % 40));
    final breathe = 1 + 0.018 * math.sin(phase / 40 * 2 * math.pi);
    return Container(
      key: const Key('crew.hero'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(tint, Colors.white, 0.35)!, tint],
        ),
        border: Border.all(color: Skin.outline, width: 2.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: edge,
              boxShadow: [BoxShadow(color: edge.withValues(alpha: 0.6), blurRadius: 10)],
            ),
            child: Transform.scale(
              scale: breathe,
              alignment: Alignment.bottomCenter,
              child: PbCardFront(crew: def, rarity: rarity, name: name, silhouette: !owned),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: info),
        ],
      ),
    );
  }
}

/// 능력치 한 줄 값: 지금 · 다음(없으면 null) · 막대 최대.
typedef StatRow = ({String label, String text, double now, double? next, double max});

/// 공격력(이 선원 초당 피해)·공격 속도(초당 발사)·사거리·특성 세기 — 막대 + 초록 미리보기 꼬리.
List<StatRow> crewStats(AppLocalizations l, GameState s, GameTables t, CrewDef def, int rarityIndex) {
  final crew = s.crews[def.id];
  // 선원마다 실제 공격(등급 템포·사거리 reach 반영 — 경제 crewAttack, 상세 특색 줄과 같은 값).
  final a = crewAttack(t, def.id, rarityIndex);
  double rate(AttackDef x) => x.intervalSec <= 0 ? 0 : x.shots * x.burst * x.projectiles / x.intervalSec;
  double reach(AttackDef x) => x.raw.numberOr('reach', 0);
  final all = [for (final c in t.crews.crews) crewAttack(t, c.id, rarityIndex)];
  final lastRarity = t.rarities.rarities.length - 1;
  final nextRate = rarityIndex < lastRarity ? rate(crewAttack(t, def.id, rarityIndex + 1)) : null;
  final rows = <StatRow>[];
  if (crew != null) {
    final now = fleetDps(s, t, [def.id]);
    final up = s.copyWith(
      crews: {
        ...s.crews,
        def.id: crew.copyWith(level: crew.level + 1),
      },
    );
    final next = fleetDps(up, t, [def.id]);
    // 막대 최대 = 함대에서 가장 센 선원의 다음 레벨(이 선원이 얼마나 센지 비교로).
    var top = next.toDouble();
    for (final id in s.crews.keys) {
      top = math.max(top, fleetDps(s, t, [id]).toDouble());
    }
    rows.add((label: l.uiStatAttack, text: now.format(), now: now.toDouble(), next: next.toDouble(), max: top));
  }
  rows
    ..add((
      label: l.uiStatSpeed,
      text: l.uiStatPerSec(shortDecimal(rate(a))),
      now: rate(a),
      // 다음 등급 템포(빨라지면 초록 꼬리).
      next: nextRate != null && nextRate > rate(a) ? nextRate : null,
      max: [for (final x in all) rate(x)].reduce(math.max),
    ))
    ..add((
      label: l.uiStatRange,
      text: rangeText(l, rangeLevel(reach(a))),
      now: reach(a),
      next: null,
      max: [for (final x in all) reach(x)].reduce(math.max),
    ));
  // 특성 세기: 등급마다 배율(전설 = 100%), 다음 등급 미리보기.
  final scale = t.skills.traitScale;
  final legendIndex = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  if (t.skills.legendFor(def.id, legendIndex, legendIndex) != null && scale.isNotEmpty) {
    double at(int i) => i >= legendIndex || i >= scale.length ? 1 : scale[i];
    final now = at(rarityIndex);
    rows.add((
      label: l.uiStatTrait,
      text: percentText(l, now),
      now: now,
      next: now < 1 ? at(rarityIndex + 1) : null,
      max: 1,
    ));
  }
  return rows;
}

class CrewStatBars extends ConsumerWidget {
  const CrewStatBars({required this.def, required this.rarityIndex, super.key});

  final CrewDef def;
  final int rarityIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final rows = crewStats(l, ref.watch(gameStateProvider), t, def, rarityIndex);
    return Padding(
      key: const Key('crew.stats'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [for (final r in rows) _Bar(row: r)]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.row});

  final StatRow row;

  @override
  Widget build(BuildContext context) {
    final r = row;
    double frac(double v) => r.max <= 0 ? 0 : (v / r.max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(r.label, style: Skin.bold(13))),
          Expanded(
            child: SizedBox(
              height: 12,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Skin.track, borderRadius: BorderRadius.circular(6)),
                    ),
                    if (r.next case final n?)
                      Container(
                        key: Key('crew.stat.next.${r.label}'),
                        width: box.maxWidth * frac(n),
                        decoration: BoxDecoration(color: Skin.mint, borderRadius: BorderRadius.circular(6)),
                      ),
                    Container(
                      width: box.maxWidth * frac(r.now),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Skin.goldTop, Skin.goldBottom]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Skin.outline, width: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(
              r.text,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Skin.text(12, color: Skin.sub),
            ),
          ),
        ],
      ),
    );
  }
}

/// 등급 사다리: 지난 칸 채움 · 지금 칸 빛남(등급 색 테·그림자) · 앞 칸 흐림.
class RarityLadder extends ConsumerWidget {
  const RarityLadder({required this.rarityIndex, super.key});

  final int rarityIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rarities = ref.watch(tablesProvider).rarities.rarities;
    return Padding(
      key: const Key('crew.ladder'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (final (i, r) in rarities.indexed)
            Expanded(
              child: Container(
                key: i == rarityIndex ? const Key('crew.ladder.now') : null,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: i <= rarityIndex
                      ? rarityColor(r).withValues(alpha: i == rarityIndex ? 0.9 : 0.45)
                      : Skin.track,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == rarityIndex ? Skin.outline : Colors.transparent,
                    width: i == rarityIndex ? 2 : 0,
                  ),
                  boxShadow: i == rarityIndex
                      ? [BoxShadow(color: rarityColor(r).withValues(alpha: 0.8), blurRadius: 8)]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tableText(l, r.nameKey),
                    style: Skin.bold(11, color: i <= rarityIndex ? Skin.ink : Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
