import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/enemy_look.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

/// 적 [n]마리가 x 120부터 16px 간격으로 서 있는 틱.
RecordedTick _crowd(int t, int n, {List<GameEvent> events = const []}) => tickOf(
  t,
  enemies: [for (var i = 0; i < n; i++) (i + 1, 120.0 + 16 * i)],
  events: events,
);

BattleScene _play(List<RecordedTick> ticks, {double ticksToPlay = 1.2}) {
  final s = BattleScene(tables, ticks, loop: false);
  var t = 0.0;
  while (t < ticksToPlay * tickMs) {
    s.update(kFrameMs);
    t += kFrameMs;
  }
  return s;
}

void main() {
  final fx = tables.fxMap;

  group('수용 기준 1: 스킬 시전', () {
    test('lob_rain은 explosion_aoe를 skillFxScale배로', () {
      final s = _play([
        _crowd(0, 3),
        _crowd(
          1,
          3,
          events: [const SkillCast(1, crewId: 'octo', skillId: 'lob_rain', x: 150, y: 100)],
        ),
        _crowd(2, 3),
      ]);
      final sheet = fx.sheet('explosion_aoe')!;
      final e = s.effects.active.where((e) => e.sheetId == 'explosion_aoe').single;
      expect(e.w, sheet.w * fx.skillFxScale);
      expect((e.x, e.y), (150, 100));
    });

    test('배 스킬(support_rally)은 배 위 level_up과 회복 번쩍임', () {
      final s = _play([
        _crowd(0, 3),
        _crowd(
          1,
          3,
          events: [const SkillCast(1, crewId: 'cook', skillId: 'support_rally', x: 0, y: 0)],
        ),
        _crowd(2, 3),
      ]);
      final e = s.effects.active.where((e) => e.sheetId == 'level_up').single;
      expect((e.x, e.y), (kShipCenterX, kShipTop + kShipHeight), reason: 'level_up은 아래 끝 기준');
      expect(s.shipHealMs, greaterThan(0));
    });
  });

  group('수용 기준 2: 화면 스킬 (SkillCast.scope)', () {
    List<RecordedTick> cast(String scope) => [
      _crowd(0, 10),
      _crowd(
        1,
        10,
        events: [
          SkillCast(1, crewId: 'pang', skillId: 'direct_snipe', x: 150, y: 100, scope: scope),
          for (var i = 1; i <= 10; i++) Damage(1, targetId: i, amount: BigNum.from(5), crewId: 'pang'),
        ],
      ),
      _crowd(2, 10),
    ];

    test('scope screen이면 화면 전체 연출', () {
      final s = _play(cast('screen'));
      expect(s.screenFlashMs, greaterThan(0));
      expect(s.effects.active.where((e) => e.sheetId == 'hit_spark').length, greaterThanOrEqualTo(10));
      expect(s.effects.active.length, lessThanOrEqualTo(tables.juice.maxEffects));
    });

    test('scope normal이면 보통 스킬 (대상이 많아도)', () {
      final s = _play(cast('normal'));
      expect(s.screenFlashMs, lessThanOrEqualTo(0));
    });
  });

  group('수용 기준 3: 궁극기 패턴', () {
    test('계열 궁극기 8종 모두 패턴이 있다', () {
      for (final f in tables.skills.families) {
        expect(fx.ultimates.containsKey(f.ultimateId), isTrue, reason: f.ultimateId);
      }
    });

    test('sweep은 durationMs 중간에 시작·끝의 가운데를 지난다', () {
      final pattern = fx.ultimates['ult_tidal_wave']!;
      final halfTicks = pattern.durationMs / 2 / tickMs;
      final s = _play([
        for (var t = 0; t < 30; t++)
          _crowd(
            t,
            5,
            events: [if (t == 1) const UltimateCast(1, crewId: 'octo', ultimateId: 'ult_tidal_wave')],
          ),
      ], ticksToPlay: 1 + halfTicks);
      final wave = s.effects.active.where((e) => e.sheetId == 'tidal_wave').single;
      final from = pattern.raw.numberOr('fromX', 0);
      final to = pattern.raw.numberOr('toX', kLogicalWidth);
      expect(wave.x, closeTo((from + to) / 2, 12));
    });

    test('8종을 한 틱에 터뜨려도 동시 이펙트 40 이하', () {
      final s = BattleScene(tables, [
        _crowd(0, 12),
        _crowd(
          1,
          12,
          events: [
            for (final f in tables.skills.families) UltimateCast(1, crewId: 'octo', ultimateId: f.ultimateId),
          ],
        ),
        for (var t = 2; t < 40; t++) _crowd(t, 12),
      ], loop: false);
      for (var i = 0; i < 120; i++) {
        s.update(kFrameMs);
        expect(s.effects.active.length, lessThanOrEqualTo(tables.juice.maxEffects));
      }
    });
  });

  test('수용 기준 5: 기절한 적은 별 표시 대상이고, 풀리면 꺼진다', () {
    RecordedTick at(int t, {required bool stunned}) => RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        enemies: [EnemyView(id: 1, kind: 'crab', x: 200, y: 100, hpRatio: 1, stunned: stunned)],
      ),
      const [],
    );
    final s = _play([
      at(0, stunned: true),
      at(1, stunned: true),
      at(2, stunned: false),
      at(3, stunned: false),
    ], ticksToPlay: 0.5);
    expect(s.poseOf(1)!.stunned, isTrue);
    final later = _play([
      at(0, stunned: true),
      at(1, stunned: true),
      at(2, stunned: false),
      at(3, stunned: false),
    ], ticksToPlay: 2.5);
    expect(later.poseOf(1)!.stunned, isFalse);
  });

  group('수용 기준 6: 적 역할 모양', () {
    test('regions.json의 모든 적 종류에 모양이 있고 모르는 종류는 basic', () {
      final looks = EnemyLooks.fromTables(tables);
      for (final e in looks.kinds) {
        expect(looks.sizeOf(e), greaterThan(0), reason: e);
      }
      expect(looks.colorOf('no_such_enemy'), fx.enemyLook['basic']!.color);
    });

    test('role을 읽고, _small은 작은 크기', () {
      final looks = EnemyLooks.fromRegionsJson(fx, '''
        {"enemies": [
          {"id": "lavacrab", "layer": "surface", "role": "tough"},
          {"id": "icecrab_small", "layer": "surface", "role": "basic"},
          {"id": "stormgull", "layer": "air"}
        ]}''');
      expect(looks.sizeOf('lavacrab'), fx.enemyLook['tough']!.size);
      expect(looks.sizeOf('icecrab_small'), fx.enemySmallSize);
      expect(looks.colorOf('stormgull'), fx.enemyLook['air']!.color);
    });
  });

  test('수용 기준 7: 분열 — Kill 직후 같은 자리 새 id 2개', () {
    final s = _play([
      tickOf(0, enemies: [(1, 200)]),
      tickOf(
        1,
        enemies: [(2, 202), (3, 198)],
        events: [Kill(1, targetId: 1, gold: BigNum.from(1), x: 200, y: 100)],
      ),
      tickOf(2, enemies: [(2, 200), (3, 196)]),
    ]);
    expect(s.stats.splitPops, 1);
    expect(s.poseCount, 2);
  });

  test('수용 기준 8: 부활 — Kill 없이 hpRatio가 다시 오른다', () {
    RecordedTick at(int t, double hp) => RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        enemies: [EnemyView(id: 1, kind: 'skeleton', x: 200, y: 100, hpRatio: hp)],
      ),
      const [],
    );
    final s = _play([at(0, 0.05), at(1, 0.5), at(2, 0.5)]);
    expect(s.stats.revives, 1);
    expect(s.poseOf(1), isNotNull);
  });

  test('수용 기준 9: 수중 장판 (ZoneSpawned) — ticks 뒤 사라진다', () {
    const zoneTicks = 40;
    final ticks = [
      _crowd(0, 3),
      _crowd(
        1,
        3,
        events: [const ZoneSpawned(1, crewId: 'octo', x: 150, y: 124, radius: 20, ticks: zoneTicks)],
      ),
      for (var t = 2; t < zoneTicks + 10; t++) _crowd(t, 3),
    ];
    final s = _play(ticks, ticksToPlay: 2);
    expect(s.zones.active, hasLength(1));
    expect(s.zones.active.single.radius, 20);
    final later = _play(ticks, ticksToPlay: zoneTicks + 4.0);
    expect(later.zones.active, isEmpty);
  });
}
