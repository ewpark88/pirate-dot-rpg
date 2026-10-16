import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 바다 괴물 도감 경제 계약 (S1 2026-10-16, UI S4 apps/game/lib/ui/dex): 만남·처치 수·첫 처치 젬.
// 전투가 틱마다 [recordDex]를 부른다(전장에 있는 kind, 이번 틱 처치 kind → 수). 빠른 항해(돌파) 중엔 부르지 않는다 — 건너뛰기와 끝까지 돈 것이 같은 젬.
// 도감 칸 = 표의 잡몹(분열로 생기는 작은 것 빼고) + 보스(해역 일반·중간·해역·순환·벽). 그 밖의 kind(보스 촉수 등)는 세지 않는다.

final _catalogs = Expando<Map<String, bool>>('dexCatalog');

/// 도감에 오르는 id → 보스인가 (표마다 한 번 계산 — 전투가 틱마다 부른다).
Map<String, bool> dexCatalog(GameTables t) => _catalogs[t] ??= _catalog(t);

Map<String, bool> _catalog(GameTables t) {
  final r = t.regions;
  final children = {for (final e in r.enemies.values) ?e.splitInto};
  return {
    for (final region in r.regions) ...{
      for (final e in region.enemies)
        if (!children.contains(e)) e: false,
      for (final b in [region.boss, region.midBoss, region.regionBoss, ...region.bossRotation, ?region.wallBoss])
        b: true,
    },
  };
}

/// 첫 처치 보상 젬 (meta.dex.firstKillGems / bossFirstKillGems, 없으면 0).
int dexFirstKillGems(GameTables t, {required bool boss}) {
  final m = t.meta.raw;
  if (!m.has('dex')) return 0;
  return m.obj('dex').numberOr(boss ? 'bossFirstKillGems' : 'firstKillGems', 0).round();
}

/// 만남·처치를 도감에 적고, 첫 처치면 젬을 준다. 바뀐 게 없으면 [s] 그대로.
GameState recordDex(
  GameState s,
  SystemContext ctx, {
  required Iterable<String> present,
  required Map<String, int> killed,
}) {
  final catalog = dexCatalog(ctx.tables);
  final dex = s.progress.dex;
  Set<String>? seen;
  Map<String, int>? kills;
  var gems = 0;
  for (final id in [...present, ...killed.keys]) {
    final boss = catalog[id];
    if (boss == null || dex.seen.contains(id) || (seen?.contains(id) ?? false)) continue;
    (seen ??= {...dex.seen}).add(id);
    ctx.emit(DexSeen(ctx.tick, id: id, boss: boss));
  }
  for (final MapEntry(key: id, value: n) in killed.entries) {
    final boss = catalog[id];
    if (boss == null || n <= 0) continue;
    final before = (kills ?? dex.kills)[id] ?? 0;
    (kills ??= {...dex.kills})[id] = before + n;
    if (before == 0) {
      final g = dexFirstKillGems(ctx.tables, boss: boss);
      gems += g;
      ctx.emit(DexFirstKill(ctx.tick, id: id, boss: boss, gems: g));
    }
  }
  if (seen == null && kills == null) return s;
  return s.copyWith(
    progress: s.progress.copyWith(
      dex: DexState(seen: seen ?? dex.seen, kills: kills ?? dex.kills),
    ),
    wallet: gems == 0 ? null : s.wallet.copyWith(gems: s.wallet.gems + gems),
  );
}
