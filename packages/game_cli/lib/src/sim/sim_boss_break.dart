import 'dart:convert';

import 'package:game_cli/src/balance/arena.dart';
import 'package:game_cli/src/sim/sim_threat.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 보스 브레이크 계측 (docs/specs/platform-fever-break.md 수용 기준 3 — S2 수치):
/// 같은 레벨 선원 한 명씩 보스전(불사 보스, 제한 시간 창)을 브레이크 끈 표·켠 표로 재서
/// - 제어 선원 = 켰을 때 보스 피해가 [controlGain] 넘게 는 선원
/// - 처치 시간 ∝ 1 ÷ 보스 피해 → 제어 선원 중앙 ÷ 제어 없는 선원 중앙(끔·켬)
/// - 창 하나당 브레이크 횟수(목표 제어 1~2 · 제어 없음 0~1, 30초 창)
class BossBreakProbe {
  BossBreakProbe(this.raw, {this.level = 45, this.stage = 2001, this.seed = 1});

  final Map<String, String> raw;
  final int level;
  final int stage;
  final int seed;
  static const controlGain = 0.05;

  GameTables _tables({required bool on}) {
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    if (!on) skills.remove('bossBreak');
    return GameTables.load({...raw, 'skills': jsonEncode(skills)});
  }

  ({double damage, int breaks}) _boss(Arena arena, String id) {
    final r = arena.run(Scene.boss, [id], level);
    return (damage: r.damageOf(id).toDouble(), breaks: r.events.whereType<BossBroken>().length);
  }

  String run() {
    final off = _tables(on: false);
    final on = _tables(on: true);
    final cfg = ArenaConfig(seed: seed, stage: stage, view: 'top');
    final a0 = Arena(off, cfg);
    final a1 = Arena(on, cfg);
    final rows = <(String, double, double, int)>[];
    for (final c in off.crews.crews) {
      final b0 = _boss(a0, c.id);
      final b1 = _boss(a1, c.id);
      rows.add((c.id, b0.damage, b1.damage, b1.breaks));
    }
    final control = rows.where((r) => r.$2 > 0 && r.$3 / r.$2 - 1 > controlGain).toList();
    final plain = rows.where((r) => !control.contains(r)).toList();
    double med(Iterable<double> xs) => SimThreat.median(xs.toList()) ?? 0;
    final ratioOff = med(plain.map((r) => r.$2)) / med(control.map((r) => r.$2));
    final ratioOn = med(plain.map((r) => r.$3)) / med(control.map((r) => r.$3));
    final b = StringBuffer()
      ..writeln('보스 브레이크 계측 — 레벨 $level · 스테이지 $stage · 창 ${off.waves.bossTimeLimitSec}초 (top)')
      ..writeln('| 선원 | 끔 피해 | 켬 피해 | 증가 | 브레이크 |')
      ..writeln('| --- | ---: | ---: | ---: | ---: |');
    for (final r in rows..sort((x, y) => (y.$3 / y.$2).compareTo(x.$3 / x.$2))) {
      final gain = r.$2 == 0 ? 0 : (r.$3 / r.$2 - 1) * 100;
      b.writeln(
        '| ${r.$1} | ${r.$2.toStringAsExponential(3)} | ${r.$3.toStringAsExponential(3)} | '
        '${gain.toStringAsFixed(1)}% | ${r.$4} |',
      );
    }
    b
      ..writeln()
      ..writeln('제어 선원 ${control.length}명: ${control.map((r) => r.$1).join(', ')}')
      ..writeln(
        '제어 처치 시간 ÷ 제어 없음 처치 시간: 끔 ${ratioOff.toStringAsFixed(3)} → 켬 ${ratioOn.toStringAsFixed(3)} (목표 0.85~1.15)',
      )
      ..writeln(
        '브레이크 횟수 중앙: 제어 ${med(control.map((r) => r.$4.toDouble()))} · '
        '제어 없음 ${med(plain.map((r) => r.$4.toDouble()))} (목표 1~2 · 0~1)',
      );
    return b.toString();
  }
}
