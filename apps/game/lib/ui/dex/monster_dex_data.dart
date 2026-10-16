import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 바다 괴물 도감 (S1 2026-10-16, S5 도감 v2 기획 승인 대기) — 화면 골격.
// 목록·그림·이름은 표(regions.json 해역별 잡몹·보스)에서 그대로. '만남·처치·처치 수'는 경제 계약 전이라 임시 규칙:
// 최고 스테이지가 그 해역에 닿았으면 만남 = 처치로 보고, 처치 수는 모름(null). 계약이 오면 [monsterDexProvider]만 바꾼다.

/// 첫 처치 보상 젬 (임시 표시값 — 기획 확정 전).
const dexFirstKillGemsPlaceholder = 5;

/// 도감 한 칸.
@immutable
class DexEntry {
  const DexEntry({required this.id, required this.boss, required this.met, required this.defeated, this.kills});

  /// 잡몹 kind 또는 보스 id.
  final String id;
  final bool boss;

  /// 만났나(그림자로 보임) · 처치했나(모습 공개).
  final bool met;
  final bool defeated;

  /// 처치 수 (계약 전엔 null).
  final int? kills;
}

/// 해역 하나의 도감 줄.
typedef DexRegion = ({RegionDef region, List<DexEntry> entries});

/// 해역 순서대로 잡몹(분열로 생기는 작은 것 제외) + 보스(일반·중간·해역).
final monsterDexProvider = Provider<List<DexRegion>>((ref) {
  final t = ref.watch(tablesProvider).regions;
  final best = ref.watch(gameStateProvider.select((s) => s.progress.bestStage));
  final seen = <String>{};
  return [
    for (final r in t.regions)
      (
        region: r,
        entries: [
          for (final e in r.enemies)
            if (!e.endsWith('_small') && seen.add(e))
              DexEntry(id: e, boss: false, met: r.fromStage <= best, defeated: r.fromStage <= best),
          for (final b in [r.boss, r.midBoss, r.regionBoss])
            if (seen.add(b))
              DexEntry(
                id: b,
                boss: true,
                met: r.fromStage <= best,
                // 해역 보스는 그 해역 끝(fromStage + 49)을 넘어야 처치.
                defeated: b == r.regionBoss ? r.fromStage + t.stagesPerRegion - 1 < best : r.fromStage <= best,
              ),
        ],
      ),
  ];
});

/// 이름 (잡몹 = ui 이름 키, 보스 = 표 nameKey).
String monsterName(AppLocalizations l, String id) => switch (id) {
  'crab' => l.uiMonsterCrab,
  'piranha' => l.uiMonsterPiranha,
  'jelly' => l.uiMonsterJelly,
  'gull' => l.uiMonsterGull,
  'urchin' => l.uiMonsterUrchin,
  'flyingfish' => l.uiMonsterFlyingfish,
  'stormgull' => l.uiMonsterStormgull,
  'puffer' => l.uiMonsterPuffer,
  'icecrab' => l.uiMonsterIcecrab,
  'penguin' => l.uiMonsterPenguin,
  'seal' => l.uiMonsterSeal,
  'snowgull' => l.uiMonsterSnowgull,
  'lavacrab' => l.uiMonsterLavacrab,
  'starfish' => l.uiMonsterStarfish,
  'lavaturtle' => l.uiMonsterLavaturtle,
  'firebird' => l.uiMonsterFirebird,
  'angler' => l.uiMonsterAngler,
  'squid' => l.uiMonsterSquid,
  'siphon' => l.uiMonsterSiphon,
  'eel' => l.uiMonsterEel,
  'skeleton' => l.uiMonsterSkeleton,
  'ghostjelly' => l.uiMonsterGhostjelly,
  'cursegull' => l.uiMonsterCursegull,
  'wraith' => l.uiMonsterWraith,
  _ => l.uiDexUnknown,
};
