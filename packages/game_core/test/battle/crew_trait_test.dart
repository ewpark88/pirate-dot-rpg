import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 개성 v2 2단계 특징(trait): 전설 능력을 일반부터 skills.json traitScale 배율로 (사용자 확인 '처음부터 약하게').
void main() {
  GameTables withScale(List<num>? scale) {
    final raw = Map<String, String>.of(rawTables);
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    if (scale == null) {
      skills.remove('traitScale');
    } else {
      skills['traitScale'] = scale;
    }
    raw['skills'] = jsonEncode(skills);
    return GameTables.load(raw);
  }

  final plain = withScale(null);
  final t = withScale([0.4, 0.6, 0.8]);
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');

  test('키가 없으면 전설 미만은 없음, 있으면 등급 배율로(연속 값 × 배율, powerScale은 전설부터)', () {
    expect(plain.skills.legendFor('starry', 0, legend), isNull);
    final common = t.skills.legendFor('starry', 0, legend)!;
    final full = t.skills.legendFor('starry', legend, legend)!;
    expect(common.onHit.burnRatio, closeTo(full.onHit.burnRatio * 0.4, 1e-9));
    expect(common.onHit.burnSec, full.onHit.burnSec, reason: '시간은 그대로, 세기만');
    expect(t.skills.legendFor('starry', 1, legend)!.onHit.burnRatio, closeTo(full.onHit.burnRatio * 0.6, 1e-9));
    expect(t.skills.legendFor('starry', 2, legend)!.onHit.burnRatio, closeTo(full.onHit.burnRatio * 0.8, 1e-9));
    expect(common.powerScale, 1);
    expect(full.powerScale, plain.skills.legendFor('starry', legend, legend)!.powerScale, reason: '전설은 지금 값');
    final octo = t.skills.legendFor('octo', 0, legend)!;
    expect(octo.zone!.slow, closeTo(t.skills.legendFor('octo', legend, legend)!.zone!.slow * 0.4, 1e-9));
  });

  test('개수형은 발마다 확률: 발사체 +1의 일반(0.4) = 40% 확률, 감쇠 없음도 배율 확률 — 결정론 난수', () {
    final crabs = t.skills.legendFor('crabs', 0, legend)!;
    expect(crabs.extraProjectiles, 0);
    expect(crabs.extraProjectilesChance, closeTo(0.4, 1e-9));
    final gull = t.skills.legendFor('gull', 1, legend)!; // +2 × 0.6 = 1.2 → 1발 + 20%
    expect(gull.extraProjectiles, 1);
    expect(gull.extraProjectilesChance, closeTo(0.2, 1e-9));
    expect(t.skills.legendFor('nar', 0, legend)!.noFalloffChance, closeTo(0.4, 1e-9));
    final rng = XorShiftRng(7);
    final n = [for (var i = 0; i < 4000; i++) roll(0.4, rng)].where((x) => x).length;
    expect(n / 4000, closeTo(0.4, 0.03));
    final a = XorShiftRng(3);
    final b = XorShiftRng(3);
    expect(roll(0, a), isFalse);
    expect(a.nextDouble(), b.nextDouble(), reason: '확률 0은 난수를 쓰지 않는다');
  });

  String run(GameTables tables) {
    final start = DateTime.utc(2026, 11);
    final e = CoreEngine(
      tables: tables,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 't', seed: 5, now: start).copyWith(
        progress: const Progress(stage: 30, bestStage: 30),
        crews: {
          for (final id in ['octo', 'crabs', 'nar', 'starry']) id: const CrewState(),
        },
      ),
    )..advance(400);
    return e.drainEvents().map((x) => x.toJson()).join();
  }

  test('배율 0이면 옛 결과와 같다, 배율이 있으면 달라지고 같은 시드는 같다', () {
    expect(run(withScale([0, 0, 0])), run(plain));
    expect(run(t), isNot(run(plain)));
    expect(run(t), run(t));
  });
}
