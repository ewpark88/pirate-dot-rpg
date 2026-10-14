import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

import 'helpers.dart';

BattleScene _scene(List<RecordedTick> ticks, {JuiceSettings settings = const JuiceSettings(), bool loop = false}) =>
    BattleScene(tables, ticks, settings: settings, loop: loop);

AttackFired _fire(int t, {String family = 'pierce', List<int> targets = const [1]}) =>
    AttackFired(t, crewId: 'octo', family: family, targetIds: targets, x: 280, y: 100);

void main() {
  group('수용 기준 2: 발사체가 피격 직전에 날아간다', () {
    test('틱 4의 발사는 표시 2에 생기고 표시 4에 닿아 사라진다', () {
      final s = _scene(
        marching(
          8,
          events: {
            4: [_fire(4)],
          },
        ),
      )..update(tickMs * 2 - 1);
      expect(s.projectiles.active, isEmpty);
      s.update(1);
      expect(s.projectiles.active, hasLength(1));
      expect(s.projectiles.active.single.progress, 0);
      s.update(tickMs);
      expect(s.projectiles.active.single.progress, closeTo(0.5, 1e-9));
      s.update(tickMs);
      expect(s.projectiles.active, isEmpty);
    });
  });

  group('수용 기준 4·5·6: 상한과 풀링', () {
    test('이펙트 60개를 요청해도 동시 이펙트는 40 이하', () {
      final s = _scene(marching(3));
      for (var i = 0; i < 60; i++) {
        s.spawnEffect('hit_spark', 100, 100);
      }
      expect(s.effects.active.length, tables.juice.maxEffects);
    });

    test('숫자 30개를 요청해도 24 이하이고 합계는 보존된다', () {
      final s = _scene(marching(3));
      for (var i = 1; i <= 30; i++) {
        s.numbers.add(BigNum.from(i), 100, 100, DamageKind.normal);
      }
      expect(s.numbers.active.length, lessThanOrEqualTo(tables.juice.maxDamageNumbers));
      final total = s.numbers.active.fold(BigNum.zero, (sum, n) => sum + n.amount);
      expect(total.toDouble(), closeTo(465, 1e-6));
    });

    test('샘플 기록을 반복 재생해도 풀이 새 객체를 만들지 않는다', () {
      final s = _scene(decodeRecording(sampleBattleJsonl), loop: true);
      for (var i = 0; i < 200; i++) {
        s.update(1000 / 60);
      }
      final created = s.stats.pooledObjects;
      for (var i = 0; i < 600; i++) {
        s.update(1000 / 60);
      }
      expect(s.stats.pooledObjects, created);
    });
  });

  group('수용 기준 7·8: 흔들림·번쩍임', () {
    final aoe = marching(
      6,
      events: {
        1: [
          Damage(1, targetId: 1, amount: BigNum.from(10)),
          AoeDamageSum(1, total: BigNum.from(10), x: 280, y: 100),
        ],
      },
    );

    test('켜져 있으면 범위 피해에 흔들리고 맞은 적이 번쩍인다', () {
      final s = _scene(aoe)
        ..update(tickMs - 1)
        ..update(2);
      expect(s.shake.peak, tables.juice.shake['aoe']!.px);
      expect(s.poseOf(1)!.flash, isTrue);
    });

    test('흔들림·번쩍임을 끄면 오프셋 0, 번쩍임 없음', () {
      final s = _scene(aoe, settings: const JuiceSettings(shake: false, flash: false))
        ..update(tickMs - 1)
        ..update(2);
      expect(s.shake.offsetX, 0);
      expect(s.shake.offsetY, 0);
      expect(s.poseOf(1)!.flash, isFalse);
    });

    test('궁극기 흔들림 진폭 = juice ultimate px', () {
      final s =
          _scene(
              marching(
                6,
                events: {
                  1: [const UltimateCast(1, crewId: 'octo', ultimateId: 'ult_tidal_wave')],
                },
              ),
            )
            ..update(tickMs - 1)
            ..update(2);
      expect(s.shake.peak, tables.juice.shake['ultimate']!.px);
    });
  });

  test('수용 기준 3: 히트스톱 구간에서 이펙트 시계가 멈춘다', () {
    final ticks = [
      tickOf(0, enemies: [(1, 300)]),
      tickOf(1, enemies: [(1, 298)]),
      tickOf(1, enemies: [(1, 298)], hitStop: 2),
      tickOf(1, enemies: [(1, 298)], hitStop: 1),
      tickOf(2, enemies: [(1, 296)]),
    ];
    final s = _scene(ticks)
      ..update(tickMs * 1.2)
      ..spawnEffect('explosion_aoe', 100, 100);
    final age = s.effects.active.single.ageMs;
    s.update(tickMs * 0.5);
    expect(s.effects.active.single.ageMs, age);
  });

  test('라이브 모드: push한 기록도 같은 연출을 낸다', () {
    final s = BattleScene(tables, null);
    for (final t in decodeRecording(sampleBattleJsonl)) {
      s
        ..push(t)
        ..update(tickMs);
    }
    expect(s.player.position, greaterThan(250));
    expect(s.player.bufferedTicks, lessThan(64));
  });

  test('수용 기준 9: 계열 8종과 support 모두 발사체 모양이 있다', () {
    final fx = tables.fxMap;
    for (final f in [...tables.skills.families.map((f) => f.id), 'shock']) {
      expect(fx.projectiles.containsKey(fx.projectileAliases[f] ?? f), isTrue, reason: f);
    }
    expect(fx.projectileFor('support'), same(fx.projectiles['shock']));
    expect(fx.projectileFor('unknown_family'), same(fx.projectiles[fx.projectileDefault]));
  });
}
