import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 스폰 패턴 섞기(사용자 지시 2026-10-15, 표 waves.top.spawnPatterns — S2): swarm·scatter·arc.
void main() {
  final t = GameTables.load();
  final w = t.waves;
  final base = TopField.of(w);
  TopField withPatterns(Map<String, double>? p) => TopField(
    width: base.width,
    height: base.height,
    shipX: base.shipX,
    shipY: base.shipY,
    shipRadius: base.shipRadius,
    mobRadius: base.mobRadius,
    bossRadius: base.bossRadius,
    spawnMargin: base.spawnMargin,
    approachRadius: base.approachRadius,
    approachBoost: base.approachBoost,
    swarmGroupsMin: base.swarmGroupsMin,
    swarmGroupsMax: base.swarmGroupsMax,
    swarmSpreadDeg: base.swarmSpreadDeg,
    separation: base.separation,
    bossStandoff: base.bossStandoff,
    bossOrbitDegPerSec: base.bossOrbitDegPerSec,
    reachScale: base.reachScale,
    swarmSpacing: base.swarmSpacing,
    viewWidth: base.viewWidth,
    viewHeight: base.viewHeight,
    mobSpeedScale: base.mobSpeedScale,
    spawnFromView: base.spawnFromView, // 표 값 그대로(S2 밀도 — 켜면 카메라 테두리 밖 출발)
    spawnPatterns: p,
    scatterGapMin: 0.3,
    scatterGapMax: 1.2,
    arcSpreadDeg: 150,
  );
  final start = DateTime.utc(2026, 11);
  SystemContext ctx(int seed) =>
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(seed), onEvent: (_) {});
  Field field() => Field(stage: 30, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100));
  double angleOf(Foe e) => math.atan2(e.y - base.shipY, e.x - base.shipX);

  test('표에 패턴이 없으면 늘 swarm — 난수 순서도 그대로(옛 결과와 같음)', () {
    List<(double, double)> run(TopField f) {
      final fl = field();
      TopGeometry(w, f).spawnWave(fl, 30, ctx(4), count: 20);
      return [for (final e in fl.foes) (e.x, e.y)];
    }

    // 옛 표 = 지금 표에서 스폰 패턴 키를 뺀 것(표에 값이 들어간 뒤에도 '키 없음 = 옛 순서'를 잰다).
    final old = TopField.of(
      WavesTable.fromJson(
        JsonReader({
          ...w.raw.raw,
          'top': {...w.raw.obj('top').raw}
            ..remove('spawnPatterns')
            ..remove('scatterGapSec')
            ..remove('arcSpreadDeg'),
        }, 'test'),
      ),
    );
    expect(run(withPatterns(null)), run(old));
  });

  test('scatter: 1~2마리씩 시간차(0.3~1.2초)로 대기, 대기 중엔 움직이지 않고 화면 밖', () {
    final g = TopGeometry(w, withPatterns({'scatter': 1}));
    final f = field();
    g.spawnWave(f, 30, ctx(7), count: 12);
    final holds = [for (final e in f.foes) e.holdSec]..sort();
    expect(holds.first, 0);
    expect(holds.last, greaterThan(0.3 * 5), reason: '12마리면 대기 묶음이 여러 개');
    final distinct = holds.toSet().toList()..sort();
    for (var i = 1; i < distinct.length; i++) {
      expect(distinct[i] - distinct[i - 1], inInclusiveRange(0.3 - 1e-9, 1.2 + 1e-9));
    }
    final waiting = f.foes.firstWhere((e) => e.holdSec > 0);
    final (x, y) = (waiting.x, waiting.y);
    expect(g.advance(waiting, 20, 0.05), isFalse);
    expect((waiting.x, waiting.y), (x, y), reason: '대기 중엔 그 자리');
    expect(g.onScreen(waiting), isFalse);
  });

  test('arc: 한 방향 반원 대열 — 모두 그 방향 ±75° 안, 여러 각도에 퍼짐', () {
    final g = TopGeometry(w, withPatterns({'arc': 1}));
    final f = field();
    g.spawnWave(f, 30, ctx(9), count: 20);
    final angles = f.foes.map(angleOf).toList();
    final mean = math.atan2(
      angles.map(math.sin).reduce((a, b) => a + b),
      angles.map(math.cos).reduce((a, b) => a + b),
    );
    for (final a in angles) {
      final d = ((a - mean + math.pi) % (2 * math.pi)) - math.pi;
      expect(d.abs(), lessThanOrEqualTo(75 * math.pi / 180 + 0.05));
    }
    final spread = angles.map((a) => ((a - mean + math.pi) % (2 * math.pi)) - math.pi).toList()..sort();
    expect(spread.last - spread.first, greaterThan(100 * math.pi / 180), reason: '넓게 펼쳐진 대열');
  });

  test('가중 추첨: 같은 시드면 같은 패턴, 많이 뽑으면 가중 비율에 가깝다', () {
    final g = TopGeometry(w, withPatterns({'swarm': 0.35, 'scatter': 0.5, 'arc': 0.15}));
    var scattered = 0;
    for (var seed = 1; seed <= 200; seed++) {
      final f = field();
      g.spawnWave(f, 30, ctx(seed), count: 6);
      if (f.foes.any((e) => e.holdSec > 0)) scattered++;
    }
    expect(scattered, inInclusiveRange(80, 120), reason: 'scatter 0.5 ≈ 100/200');
  });

  test('돌발 이벤트: 황금 물고기는 자동 조준에서 빠진다, 폭풍이면 적이 enemySpeed배로 다가온다', () {
    final g = TopGeometry(w, base);
    Foe at(double dy, {String? event}) => Foe(
      id: dy.toInt(),
      kind: 'crab',
      layer: 'surface',
      x: base.shipX,
      y: base.shipY - dy,
      maxHp: BigNum.from(1e9),
      speed: 20,
      attack: BigNum.one,
      gold: BigNum.one,
      eventKind: event,
    );
    final fish = at(60, event: 'goldfish');
    final merchant = at(70, event: 'merchant');
    expect(g.eligible(t.skills.byId('direct').attack, [fish, merchant]), [merchant]);
    final storm = t.meta.raw
        .obj('seaEvents')
        .objs('events')
        .firstWhere((e) => e.str('id') == 'storm')
        .number('enemySpeed');
    final calm = at(100);
    final windy = at(100);
    g
      ..advance(calm, 20, 0.05)
      ..speedScale = storm
      ..advance(windy, 20, 0.05);
    expect(windy.y - (base.shipY - 100), closeTo((calm.y - (base.shipY - 100)) * storm, 1e-9));
  });

  test('보물 상선(passX): 배로 오지 않고 정해진 방향으로 곧게, 밀리지 않고 겹침 풀기에서 빠지고 방향 = 지나가는 쪽', () {
    final g = TopGeometry(w, base)..speedScale = 1.3; // 폭풍이어도 배율 없음
    final ship = Foe(
      id: 1,
      kind: 'merchant',
      layer: 'surface',
      x: base.shipX - 120,
      y: base.shipY + base.shipRadius + 50,
      maxHp: BigNum.from(1e9),
      speed: 10,
      attack: BigNum.one,
      gold: BigNum.one,
      eventKind: 'merchant',
      passX: 1,
      passY: 0,
    );
    final (x0, y0) = (ship.x, ship.y);
    expect(g.advance(ship, 10, 0.5), isFalse, reason: '접촉 공격 없음');
    expect(ship.x, closeTo(x0 + 5, 1e-9));
    expect(ship.y, y0);
    g
      ..push(ship, 30)
      ..pull(ship, base.shipX, base.shipY, 30);
    expect((ship.x, ship.y), (x0 + 5, y0), reason: '밀기·끌기 무시');
    expect(g.heading(ship), 0, reason: '오른쪽으로 지나감');
  });

  test('scatterSpanSec: 흩뿌림 누적 대기를 상한까지 줄인다(간격 비율 그대로) — 0이면 그대로', () {
    double lastHold(double span) {
      final raw = {
        ...w.raw.raw,
        'top': {...w.raw.obj('top').raw, 'scatterSpanSec': span},
      };
      final g = TopGeometry(w, TopField.of(WavesTable.fromJson(JsonReader(raw, 'test'))));
      final p = withPatterns({'scatter': 1});
      final f = field();
      TopGeometry(
        w,
        TopField(
          width: p.width,
          height: p.height,
          shipX: p.shipX,
          shipY: p.shipY,
          shipRadius: p.shipRadius,
          mobRadius: p.mobRadius,
          bossRadius: p.bossRadius,
          spawnMargin: p.spawnMargin,
          approachRadius: p.approachRadius,
          approachBoost: p.approachBoost,
          swarmGroupsMin: p.swarmGroupsMin,
          swarmGroupsMax: p.swarmGroupsMax,
          swarmSpreadDeg: p.swarmSpreadDeg,
          separation: p.separation,
          bossStandoff: p.bossStandoff,
          bossOrbitDegPerSec: p.bossOrbitDegPerSec,
          reachScale: p.reachScale,
          viewWidth: p.viewWidth,
          viewHeight: p.viewHeight,
          spawnPatterns: p.spawnPatterns,
          scatterGapMin: p.scatterGapMin,
          scatterGapMax: p.scatterGapMax,
          scatterSpanSec: g.top.scatterSpanSec,
        ),
      ).spawnWave(f, 30, ctx(7), count: 40);
      return f.foes.map((e) => e.holdSec).reduce(math.max);
    }

    expect(lastHold(0), greaterThan(4), reason: '상한 없음: 40마리면 길게 이어진다');
    expect(lastHold(4), closeTo(4, 1e-9));
  });
}
