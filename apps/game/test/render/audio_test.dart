import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

/// 피치까지 기록하는 가짜 포트.
class _Rec implements AudioPort {
  final sfx = <(String, int, double)>[];
  final bgm = <String>[];

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) => sfx.add((id, variant, pitch));

  @override
  void playBgm(String id) => bgm.add(id);

  @override
  void stopBgm() => bgm.add('stop');

  @override
  void setVolumes({required double sfx, required double bgm}) {}
}

BattleScene _play(List<RecordedTick> ticks, AudioPort? audio, {double untilTicks = 8, double frameMs = kFrameMs}) {
  final s = BattleScene(tables, ticks, loop: false)..audio = audio;
  var t = 0.0;
  while (t < untilTicks * tickMs) {
    s.update(frameMs);
    t += frameMs;
  }
  return s;
}

String _sfx(String event) => tables.fxMap.events[event]!.str('sfx');

void main() {
  test('수용 기준 1: 이벤트 순서대로 fx_map sfx id', () {
    final audio = SilentAudio();
    _play([
      tickOf(0, enemies: [(1, 200)]),
      tickOf(
        1,
        enemies: [(1, 200)],
        events: [Damage(1, targetId: 1, amount: BigNum.from(1))],
      ),
      tickOf(2, events: [Kill(2, targetId: 1, gold: BigNum.from(1), x: 200, y: 100)]),
      tickOf(3, events: [const BossSpawned(3, kind: 'enemy_ship', timeLimitTicks: 600)]),
      for (var t = 4; t < 9; t++) tickOf(t),
    ], audio);
    final ids = [for (final c in audio.calls.where((c) => c.startsWith('sfx:'))) c.split(':')[1]];
    expect(ids, [_sfx('damage'), _sfx('kill'), _sfx('bossSpawned')]);
  });

  test('수용 기준 2: 변형 0~2, 피치 1±0.08, 같은 기록이면 같은 순서', () {
    List<RecordedTick> hits() => [
      tickOf(0, enemies: [(1, 200)]),
      for (var t = 1; t <= 10; t++)
        tickOf(
          t,
          enemies: [(1, 200)],
          events: [Damage(t, targetId: 1, amount: BigNum.from(1))],
        ),
      for (var t = 11; t < 14; t++) tickOf(t, enemies: [(1, 200)]),
    ];
    final a = _Rec();
    final b = _Rec();
    // 틱의 절반씩 진행: 두 타격이 한 프레임에 겹쳐 간격 규칙으로 빠지지 않게.
    _play(hits(), a, untilTicks: 13, frameMs: tickMs / 2);
    _play(hits(), b, untilTicks: 13, frameMs: tickMs / 2);
    final variants = tables.juice.raw.obj('sound').integer('hitVariants');
    final jitter = tables.juice.raw.obj('sound').number('pitchJitter');
    expect(a.sfx, hasLength(10));
    for (final (_, v, p) in a.sfx) {
      expect(v, inInclusiveRange(0, variants - 1));
      expect(p, inInclusiveRange(1 - jitter, 1 + jitter));
    }
    expect(a.sfx.map((e) => e.$2).toSet().length, greaterThan(1), reason: '변형이 섞인다');
    expect(a.sfx, b.sfx);
  });

  test('수용 기준 3: 한 틱 Damage 20개 → 프레임 상한·같은 id 간격', () {
    final audio = _Rec();
    _play([
      tickOf(0, enemies: [for (var i = 1; i <= 20; i++) (i, 100.0 + i * 8)]),
      tickOf(
        1,
        enemies: [for (var i = 1; i <= 20; i++) (i, 100.0 + i * 8)],
        events: [
          for (var i = 1; i <= 20; i++) Damage(1, targetId: i, amount: BigNum.from(1), crit: i.isEven),
        ],
      ),
      for (var t = 2; t < 6; t++) tickOf(t),
    ], audio);
    final maxPerFrame = tables.fxMap.audio.integer('sfxMaxPerFrame');
    expect(audio.sfx.length, lessThanOrEqualTo(maxPerFrame));
    expect(audio.sfx.map((e) => e.$1).toSet(), {_sfx('damage'), _sfx('critHit')}, reason: '같은 id는 간격 안에 한 번');
  });

  test('수용 기준 4: 해역이 바뀌면 bgm 한 번씩', () {
    RecordedTick at(int t, int stage) =>
        RecordedTick(BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), stage: stage), const []);
    final audio = _Rec();
    _play([at(0, 50), at(1, 50), at(2, 51), for (var t = 3; t < 8; t++) at(t, 51)], audio);
    expect(audio.bgm, ['bgm_coral', 'bgm_storm']);
  });

  test('수용 기준 5: audio가 없으면 아무 일 없음', () {
    final s = _play([
      tickOf(0, enemies: [(1, 200)]),
      tickOf(
        1,
        enemies: [(1, 200)],
        events: [Damage(1, targetId: 1, amount: BigNum.from(1))],
      ),
      for (var t = 2; t < 5; t++) tickOf(t),
    ], null);
    expect(s.audioLog, isEmpty);
  });
}
