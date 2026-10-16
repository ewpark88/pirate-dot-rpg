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
    // 사용자 지시 '폭탄이 너무 빠르다': 날아가는 시간 = fx_map projectiles.<계열>.flightMs, 도착은 엔진 피해 틱 그대로.
    double flightTicks(String family) => tables.fxMap.raw.obj('projectiles').obj(family).number('flightMs') / tickMs;

    test('투척(flightMs)은 도착 틱보다 그만큼 먼저 떠서, 도착 틱에 닿아 사라진다', () {
      final fly = flightTicks('lob');
      expect(fly, greaterThanOrEqualTo(12), reason: '눈에 보이게 0.6초 이상');
      final s = _scene(
        marching(
          26,
          events: {
            20: [_fire(20, family: 'lob')],
          },
        ),
      );
      void to(double pos) {
        while (s.player.position < pos) {
          s.update(1);
        }
      }

      to(20 - fly - 0.01);
      expect(s.projectiles.active.every((p) => p.progress == 0), isTrue, reason: '아직 출발 전');
      to(20 - fly / 2);
      expect(s.projectiles.active.single.progress, closeTo(0.5, 0.02));
      to(20.01);
      s.update(1);
      expect(s.projectiles.active, isEmpty, reason: '엔진 피해 틱(20)에 도착');
    });

    test('직선 계열은 투척보다 짧게 난다 (1배속 비행 시간)', () {
      expect(flightTicks('pierce'), lessThan(flightTicks('lob')));
      // 사용자 지시 '그림이 보이게': 1배속 투척 약 1.4초, 직사 약 0.8초. 배속이 오르면 틱이 빨라져 같이 빨라진다.
      expect(flightTicks('direct') * tickMs, inInclusiveRange(600, 900));
      expect(flightTicks('lob') * tickMs, inInclusiveRange(1100, 1400));
      expect(tables.juice.lookaheadTicks, greaterThanOrEqualTo(flightTicks('lob')), reason: '표시 지연이 가장 긴 비행을 덮는다');
    });
  });

  test('배속 2배면 같은 발사체가 실제 시간 절반에 도착한다', () {
    double arriveMs(int speed) {
      final ticks = [
        for (var i = 0; i < 60; i++)
          tickOf(
            i,
            enemies: [(1, 200)],
            speed: speed,
            events: i == 40 ? [_fire(40, family: 'lob')] : const [],
          ),
      ];
      final s = _scene(ticks);
      var ms = 0.0;
      var seen = false;
      while (ms < 6000) {
        s.update(10);
        ms += 10;
        if (s.projectiles.active.any((p) => p.progress > 0)) seen = true;
        if (seen && s.projectiles.active.isEmpty) return ms;
      }
      return ms;
    }

    final one = arriveMs(1);
    final two = arriveMs(2);
    expect(two, closeTo(one / 2, one * 0.1));
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

    test('범위 피해는 합산 숫자만, 치명타는 따로 보인다 (render-quality-v1 규칙 4, 기준 show=False)', () {
      List<RecordedTick> volley(List<GameEvent> hits) => [
        for (var i = 0; i < 3; i++)
          tickOf(i, enemies: [(1, 200), (2, 210), (3, 220)], events: i == 1 ? hits : const []),
      ];
      final s = _scene(
        volley([
          Damage(1, targetId: 1, amount: BigNum.from(40)),
          Damage(1, targetId: 2, amount: BigNum.from(40)),
          Kill(1, targetId: 2, gold: BigNum.from(7), x: 210, y: 100),
          Damage(1, targetId: 3, amount: BigNum.from(80), crit: true),
          AoeDamageSum(1, total: BigNum.from(160), x: 210, y: 100),
          Damage(1, targetId: 1, amount: BigNum.from(18)),
        ]),
      )..update(tickMs + 1);
      expect(s.numbers.active.map((n) => (n.kind, n.amount.toDouble())), [
        (DamageKind.crit, 80.0),
        (DamageKind.sum, 160.0),
        (DamageKind.normal, 18.0),
      ]);
    });

    test('샘플 기록을 반복 재생해도 풀이 새 객체를 만들지 않는다', () {
      final rec = decodeRecording(sampleBattleJsonl);
      final s = _scene(rec, loop: true);
      // 워밍업 = 샘플 한 바퀴 전부(가장 붐비는 순간이 어디든 풀이 다 자라게 — 엔진이 바뀌면 샘플도 다시 뽑힌다).
      final loopFrames = (rec.length * tables.waves.tickMs / (1000 / 60)).ceil() + 60;
      for (var i = 0; i < loopFrames; i++) {
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
