import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 바다 괴물 도감 (S1 2026-10-16) — 목록·그림·이름은 표(regions.json 해역별 잡몹·보스)에서 그대로.
// 만남·처치 수는 경제 계약 progress.dex{seen, kills}(S2 7ac7efb0). 칸 목록은 코어 dexCatalog와 같은 규칙:
// 잡몹(분열로 생기는 작은 것 빼고) + 보스(일반·중간·해역·순환·벽).

/// 첫 처치 보상 젬 (meta.dex.firstKillGems / bossFirstKillGems, 없으면 0 — 코어 dexFirstKillGems와 같은 값).
int dexFirstKillGems(GameTables t, {required bool boss}) {
  final m = t.meta.raw;
  if (!m.has('dex')) return 0;
  return m.obj('dex').numberOr(boss ? 'bossFirstKillGems' : 'firstKillGems', 0).round();
}

/// 도감 한 칸.
@immutable
class DexEntry {
  const DexEntry({required this.id, required this.boss, required this.met, required this.defeated, this.kills = 0});

  /// 잡몹 kind 또는 보스 id.
  final String id;
  final bool boss;

  /// 만났나(그림자로 보임) · 처치했나(모습 공개).
  final bool met;
  final bool defeated;

  /// 처치 수.
  final int kills;
}

/// 해역 하나의 도감 줄.
typedef DexRegion = ({RegionDef region, List<DexEntry> entries});

/// 해역 순서대로 잡몹(분열로 생기는 작은 것 제외) + 보스(일반·중간·해역·순환·벽). 한 번 나온 id는 뒤 해역에서 뺀다.
final monsterDexProvider = Provider<List<DexRegion>>((ref) {
  final t = ref.watch(tablesProvider).regions;
  final dex = ref.watch(gameStateProvider.select((s) => s.progress.dex));
  final children = {for (final e in t.enemies.values) ?e.splitInto};
  final listed = <String>{};
  DexEntry entry(String id, {required bool boss}) {
    final kills = dex.killsOf(id);
    return DexEntry(id: id, boss: boss, met: kills > 0 || dex.seen.contains(id), defeated: kills > 0, kills: kills);
  }

  return [
    for (final r in t.regions)
      (
        region: r,
        entries: [
          for (final e in r.enemies)
            if (!children.contains(e) && listed.add(e)) entry(e, boss: false),
          for (final b in [r.boss, r.midBoss, r.regionBoss, ...r.bossRotation, ?r.wallBoss])
            if (listed.add(b)) entry(b, boss: true),
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
