import 'dart:convert';

import 'package:game_cli/src/balance/arena.dart';
import 'package:game_cli/src/sim/sim_threat.dart';
import 'package:game_data/game_data.dart';

/// 보스 특성 보정 계측 (docs/specs/economy-boss-traits.md 3절): 선원 40명 단독 보스전(불사 보스, 30초 창)을 특성 끔·켬으로 재서
/// hpFactor = 켬 중앙 ÷ 끔 중앙(보스 HP에 곱하면 평균 처치 시간이 같아진다 — 표 bossTraits.hpFactor), 보정 뒤 카운터·비카운터 계열 중앙 증감.
/// 끔 = hpFactor를 빼고 잰다(보정 전 효과).
/// 성립 조건: 카운터 +15% 이상, 비카운터 −25% 이내.
class BossTraitProbe {
  BossTraitProbe(this.raw, this.trait, {this.level = 45, this.stage = 2001, this.seed = 1});

  final Map<String, String> raw;
  final String trait;
  final int level;
  final int stage;
  final int seed;

  GameTables _with(GameTables base) {
    final regions = jsonDecode(raw['regions']!) as Map<String, dynamic>;
    final id = base.regions.bossAt(stage).id;
    for (final b in (regions['bosses'] as List).cast<Map<String, dynamic>>()) {
      if (b['id'] == id) b['traits'] = [trait];
    }
    return GameTables.load({...raw, 'regions': jsonEncode(regions)});
  }

  String run() {
    final off = GameTables.load(raw);
    final on = _with(off);
    final counters = on.regions.bossAt(stage).counterFamilies.toSet();
    final cfg = ArenaConfig(seed: seed, stage: stage, view: 'top');
    final a0 = Arena(off, cfg);
    final a1 = Arena(on, cfg);
    final rows = <(String, String, double, double)>[];
    for (final c in off.crews.crews) {
      final d0 = a0.run(Scene.boss, [c.id], level).damageOf(c.id).toDouble();
      final d1 = a1.run(Scene.boss, [c.id], level).damageOf(c.id).toDouble();
      rows.add((c.id, c.family, d0, d1));
    }
    double med(Iterable<double> xs) => SimThreat.median(xs.toList()) ?? 0;
    final comp = med(rows.map((r) => r.$3)) / med(rows.map((r) => r.$4));
    double gain(Iterable<(String, String, double, double)> rs) => med(rs.map((r) => r.$4 * comp / r.$3)) - 1;
    final counter = rows.where((r) => counters.contains(r.$2));
    final other = rows.where((r) => !counters.contains(r.$2));
    final cg = gain(counter);
    final og = gain(other);
    final ok = cg >= 0.15 && og >= -0.25;
    return '보스 특성 $trait — 레벨 $level · hpFactor ${(1 / comp).toStringAsFixed(3)} · '
        '보정 뒤 카운터(${counters.join('·')}) ${(cg * 100).toStringAsFixed(1)}% · 비카운터 ${(og * 100).toStringAsFixed(1)}% · '
        '${ok ? 'OK' : '벗어남(카운터 +15% 이상·비카운터 −25% 이내)'}\n';
  }
}
