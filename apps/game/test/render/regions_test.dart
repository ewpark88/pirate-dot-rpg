import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/enemy_look.dart';
import 'package:pirate_dot/render/scene/backdrop.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

RecordedTick _boss(int t, {List<GameEvent> events = const [], bool alive = true}) => RecordedTick(
  BattleView(
    tick: t,
    shipHp: BigNum.from(60),
    shipHpMax: BigNum.from(60),
    bossActive: alive,
    enemies: [
      if (alive) const EnemyView(id: 99, kind: 'storm_pirate', x: 260, y: 100, hpRatio: 0.2, boss: true),
      EnemyView(id: 1, kind: 'crab', x: 200 - t * 2.0, y: 100, hpRatio: 1),
    ],
  ),
  events,
);

BattleScene _play(List<RecordedTick> ticks, double untilTicks, {JuiceSettings settings = const JuiceSettings()}) {
  final s = BattleScene(tables, ticks, loop: false, settings: settings);
  var t = 0.0;
  while (t < untilTicks * tickMs) {
    s.update(kFrameMs);
    t += kFrameMs;
  }
  return s;
}

void main() {
  final fx = tables.fxMap;

  test('수용 기준 1: 해역 배경 6종이 모두 있고 모르는 id는 기본', () {
    final regions = jsonDecode(rawTables['regions']!) as Map<String, dynamic>;
    for (final r in (regions['regions'] as List).cast<Map<String, dynamic>>()) {
      expect(fx.backgrounds.containsKey(r['background']), isTrue, reason: '${r['background']}');
    }
    final b = Backdrop(fx, rawTables['regions']!);
    expect(b.paletteOf('bg_nowhere').sky, b.paletteOf(fx.backgroundDefault).sky);
  });

  test('수용 기준 2: 스테이지 → 해역 배경', () {
    final b = Backdrop(fx, rawTables['regions']!);
    expect(
      [
        for (final s in [1, 50, 51, 150, 251, 400]) b.backgroundFor(s),
      ],
      [
        'bg_coral',
        'bg_coral',
        'bg_storm',
        'bg_glacier',
        'bg_phantom',
        'bg_phantom',
      ],
    );
  });

  test('수용 기준 3: 해역 전환은 backgroundFadeMs 동안 섞인다', () {
    final b = Backdrop(fx, rawTables['regions']!)..setStage(50);
    final coral = b.paletteOf('bg_coral').sky;
    final storm = b.paletteOf('bg_storm').sky;
    b
      ..setStage(51)
      ..update(fx.backgroundFadeMs / 2);
    int ch(int c, int shift) => (c >> shift) & 0xFF;
    for (final shift in [16, 8, 0]) {
      expect(ch(b.sky, shift), closeTo((ch(coral, shift) + ch(storm, shift)) / 2, 1.5));
    }
    b.update(fx.backgroundFadeMs);
    expect(b.sky, storm);
  });

  group('수용 기준 4: 보스 등장 경고', () {
    final ticks = [
      _boss(0, alive: false),
      _boss(1, events: [const BossSpawned(1, kind: 'storm_pirate', timeLimitTicks: 600)]),
      for (var t = 2; t < 40; t++) _boss(t),
    ];

    test('켜졌다가 bossEntrance.ms 뒤 꺼진다', () {
      expect(_play(ticks, 1.2).bossWarnMs, greaterThan(0));
      final after = 1 + (fx.bossEntrance.number('ms') + 100) / tickMs;
      expect(_play(ticks, after).bossWarnMs, lessThanOrEqualTo(0));
    });

    test('번쩍임 끄기면 켜지지 않는다', () {
      expect(_play(ticks, 1.2, settings: const JuiceSettings(flash: false)).bossWarnMs, lessThanOrEqualTo(0));
    });
  });

  test('수용 기준 5: 보스 처치 — 한 번만, 코인 비, 슬로모션 속도', () {
    final s = BattleScene(tables, [
      _boss(0),
      _boss(1, alive: false, events: [Kill(1, targetId: 99, gold: BigNum.from(100), x: 260, y: 100)]),
      _boss(2, alive: false, events: [const BossCleared(2, stage: 25, gems: 5)]),
      for (var t = 3; t < 30; t++) _boss(t, alive: false),
    ], loop: false);
    var t = 0.0;
    while (t < 1.05 * tickMs) {
      s.update(kFrameMs);
      t += kFrameMs;
    }
    expect(s.slowMoMs, greaterThan(0));
    expect(s.coins.active.length, tables.juice.bossCoinRain + tables.juice.coinCount);
    final before = s.player.position;
    s.update(kFrameMs);
    expect(s.player.position - before, closeTo(kFrameMs * tables.juice.bossSlowMoRate / tickMs, 1e-9));
    // 다음 틱 BossCleared가 와도 처치 연출(코인 비)이 다시 나오지 않는다.
    final coins = s.coins.active.length;
    for (var i = 0; i < 20; i++) {
      s.update(kFrameMs);
    }
    expect(s.coins.active.length, lessThanOrEqualTo(coins));
  });

  test('수용 기준 6: 보스 실패 — 잠깐 어두움, 흔들림 없음', () {
    final ticks = [
      _boss(0),
      _boss(1, events: [const BossFailed(1, stage: 25)]),
      for (var t = 2; t < 30; t++) _boss(t),
    ];
    final s = _play(ticks, 1.2);
    expect(s.bossFailMs, greaterThan(0));
    expect(s.shake.amplitude, 0);
    final after = 1 + (fx.bossFailed.number('ms') + 100) / tickMs;
    expect(_play(ticks, after).bossFailMs, lessThanOrEqualTo(0));
  });

  test('수용 기준 7: 보스 모양 13종 + 촉수, 모르는 보스는 enemy_ship', () {
    final looks = EnemyLooks.fromTables(tables);
    for (final kind in [
      'enemy_ship', 'raider_ship', 'storm_pirate', 'icebreaker', 'fire_pirate', 'deep_sub', 'ghost_ship', //
      'giant_hermit', 'thunder_ray', 'iceberg_walrus', 'lava_whale', 'kraken', 'ghost_admiral', 'kraken_tentacle',
    ]) {
      expect(looks.bossOf(kind, boss: true), isNotNull, reason: kind);
      expect(looks.bossOf(kind, boss: true)!.w, fx.bossLook[kind]!.number('w'), reason: kind);
    }
    expect(looks.bossOf('mystery_boss', boss: true)!.w, fx.bossLook['enemy_ship']!.number('w'));
    expect(looks.bossOf('crab', boss: false), isNull);
    expect(looks.bossOf('kraken_tentacle', boss: false), isNotNull, reason: '촉수는 boss 표시가 없어도 보스 모양');
  });

  test('수용 기준 8: 보호막이 깨지면 깨짐 연출 1번, 그 뒤 테두리 없음', () {
    RecordedTick at(int t, {required bool shielded}) => RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        enemies: [
          EnemyView(id: 99, kind: 'storm_pirate', x: 260, y: 100, hpRatio: 0.8, boss: true, shielded: shielded),
        ],
      ),
      const [],
    );
    final ticks = [at(0, shielded: true), at(1, shielded: true), at(2, shielded: false), at(3, shielded: false)];
    final before = _play(ticks, 0.5);
    expect(before.poseOf(99)!.shielded, isTrue);
    final s = _play(ticks, 2.5);
    expect(s.stats.shieldBreaks, 1);
    expect(s.poseOf(99)!.shielded, isFalse);
  });

  test('수용 기준 9: tier 0은 테두리 없음, 1~3은 tierColors', () {
    final looks = EnemyLooks.fromTables(tables);
    expect(looks.tierColor(0), isNull);
    for (var t = 1; t <= 3; t++) {
      expect(looks.tierColor(t), fx.tierColors[t - 1]);
    }
    expect(looks.tierColor(9), fx.tierColors.last);
  });

  test('수용 기준 11: 프레임 stage로 배경이 바뀐다', () {
    RecordedTick at(int t, int stage) =>
        RecordedTick(BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), stage: stage), const []);
    final ticks = [at(0, 50), at(1, 50), at(2, 51), for (var t = 3; t < 60; t++) at(t, 51)];
    final storm = Backdrop(fx, rawTables['regions']!).paletteOf('bg_storm').sky;
    final coral = Backdrop(fx, rawTables['regions']!).paletteOf('bg_coral').sky;
    expect(_play(ticks, 1).backdrop.sky, coral);
    expect(_play(ticks, 2 + (fx.backgroundFadeMs + 100) / tickMs).backdrop.sky, storm);
  });

  group('수용 기준 12: 보물상자', () {
    RecordedTick at(int t, {ChestView? chest}) => RecordedTick(
      BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), chest: chest),
      const [],
    );
    final bob = fx.chest.number('bobPx');
    final sinkTicks = fx.chest.integer('sinkTicks');

    test('떠 있을 때는 (x, y±bobPx), 가라앉지 않음', () {
      final s = _play([
        for (var t = 0; t < 10; t++) at(t, chest: ChestView(x: 160, y: 104, ticksLeft: 400 - t)),
      ], 3);
      expect(s.chest.visible, isTrue);
      expect(s.chest.x, 160);
      expect(s.chest.y, inInclusiveRange(104 - bob, 104 + bob));
      expect(s.chest.sink, 0);
    });

    test('남은 틱이 sinkTicks보다 적으면 가라앉는다', () {
      final s = _play([
        for (var t = 0; t < 10; t++) at(t, chest: ChestView(x: 160, y: 104, ticksLeft: sinkTicks ~/ 2 - t)),
      ], 3);
      expect(s.chest.sink, greaterThan(0));
    });

    test('chest가 없으면 안 보인다', () {
      expect(_play([for (var t = 0; t < 5; t++) at(t)], 2).chest.visible, isFalse);
    });
  });
}
