import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 보스 vs 나 (사용자 피드백 #5 '보스 공격력 표시, 내 공격력과 비교'): 이길 수 있나를 한눈에.
// 보스 체력·공격·제한 시간은 경제 bossPreview(전투와 같은 공식), 내 힘은 fleetPower.dps — UI는 나누기만 한다.

/// 처치 예상 시간 / 남은 시간 비율의 단계 — 여유(이 이하) · 빠듯(1 이하) · 어려움.
const _easy = 0.6;

/// 한 줄에 보일 값.
typedef BossCompareView = ({String hp, int killSec, int limitSec, int hitPct, int level});

/// 보스전 중이면 남은 체력·남은 시간으로, 파밍 중이면 다음 도전 기준으로 계산. 그 밖엔 null.
BossCompareView? bossCompareOf(GameState s, GameTables t) {
  final b = s.battle;
  if (b == null || !(b.bossActive || s.progress.farming)) return null;
  final p = bossPreview(s, t);
  final dps = fleetPower(s, t).dps;
  if (dps.isZero) return null;
  var hpLeft = p.maxHp;
  var limit = p.timeLimitSec;
  if (b.bossActive) {
    for (final e in b.enemies) {
      if (e.boss) hpLeft = p.maxHp.times(e.hpRatio.clamp(0.0, 1.0));
    }
    limit = b.bossTicksLeft * t.waves.tickMs / Duration.millisecondsPerSecond;
  }
  final kill = (hpLeft / dps).toDouble();
  final ratio = limit <= 0 ? double.infinity : kill / limit;
  // 한 대 피해는 엔진이 배 최대 체력 × waves.shipHitCap으로 막는다(한 방 침몰 금지) — 표시도 같은 상한.
  final cap = t.waves.raw.number('shipHitCap');
  final raw = b.shipHpMax.isZero ? 0.0 : (p.attack / b.shipHpMax).toDouble();
  final hit = (raw < cap ? raw : cap) * 100;
  return (
    hp: hpLeft.format(),
    killSec: kill.ceil(),
    limitSec: limit.ceil(),
    hitPct: hit.ceil(),
    level: ratio <= _easy ? 0 : (ratio <= 1 ? 1 : 2),
  );
}

/// 진행 게이지 안 둘째 줄(다음 목표 자리): [⚔] 보스 체력 1.2M · 약 15초 / 20초 · 한 방 12% · 여유/빠듯/어려움.
/// 보스전·파밍이 아니면 [fallback](다음 목표). 높이를 늘리지 않아 전장 가운데를 덮지 않는다.
class BossCompare extends ConsumerWidget {
  const BossCompare({required this.fallback, super.key});

  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final v = ref.watch(gameStateProvider.select((s) => bossCompareOf(s, t)));
    if (v == null) return fallback;
    final l10n = AppLocalizations.of(context);
    final color = switch (v.level) {
      0 => Skin.mint,
      1 => const Color(0xFFFFD84A),
      _ => const Color(0xFFFF6B7A),
    };
    final verdict = switch (v.level) {
      0 => l10n.uiBossCompareEasy,
      1 => l10n.uiBossCompareTight,
      _ => l10n.uiBossCompareHard,
    };
    return Row(
      key: Key('boss.compare.${v.level}'),
      children: [
        Icon(Icons.sports_martial_arts_rounded, size: 15, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.uiBossCompare(v.hp, v.killSec, v.limitSec, v.hitPct),
              key: const Key('boss.compare'),
              maxLines: 1,
              style: Skin.text(13, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(verdict, style: Skin.text(13, color: color)),
      ],
    );
  }
}
