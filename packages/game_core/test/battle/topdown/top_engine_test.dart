import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'still_ship.dart';

/// 탑다운 모드로 엔진 전체를 돌린다(Settings.battleView = top, 탑다운 전환 T1).
/// 경제(골드·처치·보스 클리어·진행)는 옆모습과 같은 코드가 한다 — 여기선 '돌아가고 이어지는가'와 모양만 본다.
void main() {
  final tables = GameTables.load(stillShipRaw());
  final top = tables.waves.top;
  final start = DateTime.utc(2026, 11);

  GameState game({String view = 'top', int seed = 7}) => GameState.newGame(
    playerId: 't',
    seed: seed,
    now: start,
    crews: tables.meta.startingCrews,
  ).copyWith(settings: Settings(battleView: view));

  CoreEngine engineOf(GameState s) => CoreEngine(tables: tables, clock: ManualClock(start), initial: s);
  int ticksFor(double sec) => (sec * 1000 / tables.waves.tickMs).round();

  test('첫 무리: 모두 배 중심에서 접근 원 밖(화면 밖), BattleView는 top·배 중심·적 방향', () {
    final e = engineOf(game())..tick();
    final b = e.state.battle!;
    expect(b.mode, 'top');
    expect((b.shipX, b.shipY), (top.shipX, top.shipY));
    expect(b.enemies, hasLength(tables.waves.topMobCountAt(1)));
    for (final x in b.enemies.where((e) => !e.emerging)) {
      // 가까이 등장(nearSpawn) 몫은 제외
      final d = math.sqrt(math.pow(x.x - top.shipX, 2) + math.pow(x.y - top.shipY, 2));
      expect(d, greaterThan(top.approachRadius * 0.9), reason: '첫 틱에 한 걸음 다가왔을 뿐');
      expect(d, greaterThan(top.shipRadius * 4));
      expect(x.heading, closeTo(math.atan2(top.shipY - x.y, top.shipX - x.x), 1e-9));
    }
  });

  test('2분 돌리면 처치·골드·스테이지가 오르고, 발사 이벤트에 포구·방향이 실린다', () {
    final e = engineOf(game());
    final fired = <(AttackFired, double, double)>[]; // 쏜 틱의 배 중심(보스전 비켜서기·피버 좌우로 움직인다)
    var kills = 0;
    var fever = false; // 피버 중엔 배가 지그재그로 움직여 포구 기준이 shipX·shipY가 아니다
    for (var i = 0; i < ticksFor(120); i++) {
      e.tick();
      final v = e.state.battle;
      for (final ev in e.drainEvents()) {
        if (ev is FeverStarted) fever = true;
        if (ev is AttackFired && !fever) fired.add((ev, v?.shipX ?? top.shipX, v?.shipY ?? top.shipY));
        if (ev is Kill) kills++;
      }
    }
    expect(kills, greaterThan(20));
    expect(e.state.wallet.gold > BigNum.zero, isTrue);
    expect(e.state.progress.stage, greaterThan(1));
    expect(fired, isNotEmpty);
    for (final (f, sx, sy) in fired.take(50)) {
      expect(f.fromX, isNotNull);
      expect(f.angle, closeTo(math.atan2(f.y - sy, f.x - sx), 1e-9));
    }
    // 사방에서 맞혔다(옆모습처럼 오른쪽만이 아님).
    final quadrants = {for (final (f, _, _) in fired) ((f.angle! + math.pi) / (math.pi / 2)).floor() % 4};
    expect(quadrants.length, greaterThanOrEqualTo(3));
  });

  test('피격 방향: ShipDamaged에 때린 적 위치(JSON 왕복)', () {
    List<ShipDamaged> hits(String view) {
      final e = engineOf(game(view: view))..enqueue(const OpSpawnBoss());
      final out = <ShipDamaged>[];
      for (var i = 0; i < ticksFor(30) && out.isEmpty; i++) {
        e.tick();
        out.addAll(e.drainEvents().whereType<ShipDamaged>());
      }
      return out;
    }

    final top = hits('top');
    expect(top, isNotEmpty);
    final h = top.first;
    expect(h.fromX, isNotNull);
    expect(GameEvent.fromJson(h.toJson()).toJson(), h.toJson());
  });

  test('적은 선체 몸통(캡슐)까지 와서 닿고 접촉 공격한다 — 멈춰 보이지 않게(사용자 신고 2026-10-15)', () {
    final e = engineOf(game().copyWith(progress: const Progress(stage: 10, bestStage: 10)));
    final geo = geometryFor(tables, 10) as TopGeometry; // 선체 1단계(시작 배)
    double gap(EnemyView x) => geo.hullGap(x.x, x.y);

    var hits = 0;
    final touched = <int>{};
    final closest = <double>[];
    for (var i = 0; i < ticksFor(20); i++) {
      e.tick();
      hits += e.drainEvents().whereType<ShipDamaged>().length;
      for (final x in e.state.battle!.enemies.where((x) => !x.boss)) {
        final g = gap(x);
        expect(g, greaterThan(top.mobRadius - 0.5), reason: '몸통 안으로 들어가지 않는다');
        if (g <= top.mobRadius + 0.5) touched.add(x.id);
      }
      final mobs = e.state.battle!.enemies.where((x) => !x.boss);
      if (i >= ticksFor(10) && mobs.isNotEmpty) {
        closest.add(mobs.map((x) => gap(x) - top.mobRadius).reduce(math.min));
      }
    }
    expect(touched.length, greaterThan(10), reason: '많은 적이 몸통에 닿는다(옆구리 포함)');
    // 보이는 거리(제안 platform-ship-hitbox C-3): 10~20초 사이 적이 있는 틱의 1/4 이상에서, 가장 가까운 적이 몸통에 닿아 있다
    // (틈 ≤ 1단위, S24 약 2dp). 틈은 '붙음 0'과 '다음 파가 다가오는 중 80~130' 두 갈래라 중앙값 대신 아래 사분위로 본다.
    // 사용자가 본 '일정 간격에서 멈춤'이 생기면 아래 사분위가 크게 벌어진다.
    expect(closest.isNotEmpty, isTrue);
    closest.sort();
    expect(closest[closest.length ~/ 4], lessThanOrEqualTo(1));
    expect(hits, greaterThan(10));
  });

  test('결정론: 같은 시드·같은 명령이면 같은 상태', () {
    String run() {
      final e = engineOf(game(seed: 11))..advance(ticksFor(60));
      return jsonEncode(e.state.battle!.toJson());
    }

    expect(run(), run());
  });

  test('보스: 위에서 나와 standoff 원에 멈추고, 원을 벗어나지 않는다', () {
    final e = engineOf(game())
      ..enqueue(const OpSpawnBoss())
      ..tick();
    double dist() {
      final v = e.state.battle!;
      final boss = v.enemies.firstWhere((x) => x.boss);
      return math.sqrt(math.pow(boss.x - (v.shipX ?? top.shipX), 2) + math.pow(boss.y - (v.shipY ?? top.shipY), 2));
    }

    final boss0 = e.state.battle!.enemies.firstWhere((x) => x.boss);
    expect(boss0.y, lessThan(top.shipY));
    // 출발 = 접근 원(bossSpawnRadius 기본) 바로 밖, 카메라 밖 (빠른 항해 보스 간격 — S2 결정 ①). 첫 틱에 한 걸음 왔을 수 있다.
    final start = math.sqrt(math.pow(boss0.x - top.shipX, 2) + math.pow(boss0.y - top.shipY, 2));
    expect(start, closeTo(tables.waves.raw.obj('top').number('bossSpawnRadius') + top.bossRadius, 5));
    expect(top.shipY - boss0.y, greaterThan(tables.waves.raw.obj('top').number('viewHeight') / 2));
    final r = bossStandoffFor(tables, boss0.kind); // 큰 보스(bossScale)는 더 멀리 선다
    var reached = false;
    for (var i = 0; i < ticksFor(25) && e.state.battle!.bossActive; i++) {
      e.tick();
      if (!e.state.battle!.enemies.any((x) => x.boss)) break;
      if (dist() <= r + 1e-6) reached = true;
      // 원 안으로는 들어오지 않고, 충격·강습에 밀려도 잠깐 바깥(밀린 만큼)이다.
      if (reached) expect(dist(), inInclusiveRange(r - 1e-6, r + 20));
    }
    expect(reached, isTrue);
  });
}
