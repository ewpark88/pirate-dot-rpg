import 'dart:convert';

import 'package:game_cli/src/balance/arena.dart';
import 'package:game_cli/src/balance/combos.dart';
import 'package:game_cli/src/balance/crew_scores.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final t = GameTables.load();
  final arena = Arena(t);
  final direct = t.crews.crews.firstWhere((c) => c.family == 'direct').id;
  final shock = t.crews.crews.firstWhere((c) => c.family == 'shock').id;

  group('Arena', () {
    test('수용 기준 2: 무리전 60초 = Damage 합, 처치 없음, 배 생존', () {
      final run = arena.run(Scene.swarm, [direct], 45);
      expect(run.ticks, arena.secondsToTicks(arena.config.seconds));
      expect(run.kills, 0);
      expect(run.shipSunk, isFalse);
      final fromEvents = run.events
          .whereType<Damage>()
          .where((e) => e.crewId == direct)
          .fold(BigNum.zero, (s, e) => s + e.amount);
      expect(run.damageOf(direct), fromEvents);
      expect(run.damageOf(direct) > BigNum.zero, isTrue);
    });

    test('수용 기준 3: 스테이지와 무관 (S, S+한 바퀴)', () {
      final loop = t.regions.loopStages;
      final a = arena.run(Scene.swarm, [direct], 45);
      final b = Arena(t, arena.config.copyWith(stage: arena.config.stage + loop)).run(Scene.swarm, [direct], 45);
      expect(b.damageOf(direct), a.damageOf(direct));
    });

    test('수용 기준 4: 보스전은 제한 시간 창, 60초 환산 배율', () {
      final run = arena.run(Scene.boss, [direct], 45);
      expect(run.ticks, arena.bossWindowTicks);
      expect(arena.bossScale, closeTo(arena.config.seconds / t.waves.bossTimeLimitSec, 1e-9));
      expect(run.kills, 0);
    });

    test('S_tank가 25의 배수면 거절 (중간·해역 보스 약점이 끼어듦)', () {
      expect(() => Arena(t, arena.config.copyWith(stage: 2000)), throwsA(isA<MeasureError>()));
    });
  });

  group('점수표', () {
    final crews = [direct, shock, ...t.crews.crews.where((c) => c.family == 'lob').take(1).map((c) => c.id)];

    test('수용 기준 1: 같은 시드면 JSON이 같다', () {
      String once() => jsonEncode(scoreCrews(t, levels: const [45], crewIds: crews, combos: 4).toJson());
      expect(once(), once());
    });

    test('수용 기준 7: 지원 선원 점수 = 자기 피해 + 파트너 증가분 + 배 보호분', () {
      final r = scoreCrews(t, levels: const [45], crewIds: crews, combos: 0);
      final s = r.crews.firstWhere((c) => c.id == shock);
      expect(s.support, isNotNull);
      final sup = s.support!;
      expect(sup.own + sup.partnerUplift + sup.shipShield, closeTo(s.score, s.score.abs() * 1e-9 + 1e-9));
      expect(r.crews.firstWhere((c) => c.id == direct).support, isNull);
    });

    test('수용 기준 5: 판정 — 중앙값 ±10% 밖이면 ✗, 보고서 실패', () {
      final verdict = judgeLevel({'a': 100, 'b': 104, 'c': 95, 'd': 120, 'e': 89});
      expect(verdict.median, 100);
      expect(verdict.failing, {'d', 'e'});
    });

    test('수용 기준 5: 한 계열 공격력 ×1.2면 그 선원 점수도 약 ×1.2', () {
      final raw = Map<String, String>.of(rawTables);
      final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
      final fam = (skills['families'] as List).cast<Map<String, dynamic>>().firstWhere((f) => f['id'] == 'direct');
      final attack = fam['attack'] as Map<String, dynamic>;
      attack['power'] = (attack['power'] as num) * 1.2;
      raw['skills'] = jsonEncode(skills);
      final boosted = GameTables.load(raw);
      final base = arena.run(Scene.boss, [direct], 45).damageOf(direct);
      final up = Arena(boosted).run(Scene.boss, [direct], 45).damageOf(direct);
      expect((up / base).toDouble(), closeTo(1.2, 0.05));
    });
  });

  test('수용 기준 6: 조합은 6명, 같은 계열 2명 이하, 시드 고정', () {
    final a = sampleCombos(t, 30, seed: 7);
    expect(a, hasLength(30));
    for (final combo in a) {
      expect(combo, hasLength(6));
      expect(combo.toSet(), hasLength(6));
      final fams = <String, int>{};
      for (final id in combo) {
        final f = t.crews.crews.firstWhere((c) => c.id == id).family;
        fams[f] = (fams[f] ?? 0) + 1;
      }
      expect(fams.values.every((n) => n <= 2), isTrue);
    }
    expect(sampleCombos(t, 30, seed: 7), a);
  });
}
