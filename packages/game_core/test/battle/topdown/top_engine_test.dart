import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 탑다운 모드로 엔진 전체를 돌린다(Settings.battleView = top, 탑다운 전환 T1).
/// 경제(골드·처치·보스 클리어·진행)는 옆모습과 같은 코드가 한다 — 여기선 '돌아가고 이어지는가'와 모양만 본다.
void main() {
  final tables = GameTables.load();
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
    expect(b.enemies, hasLength(tables.waves.mobCountAt(1)));
    for (final x in b.enemies) {
      final d = math.sqrt(math.pow(x.x - top.shipX, 2) + math.pow(x.y - top.shipY, 2));
      expect(d, greaterThan(top.approachRadius * 0.9), reason: '첫 틱에 한 걸음 다가왔을 뿐');
      expect(d, greaterThan(top.shipRadius * 4));
      expect(x.heading, closeTo(math.atan2(top.shipY - x.y, top.shipX - x.x), 1e-9));
    }
  });

  test('2분 돌리면 처치·골드·스테이지가 오르고, 발사 이벤트에 포구·방향이 실린다', () {
    final e = engineOf(game());
    final fired = <AttackFired>[];
    var kills = 0;
    for (var i = 0; i < ticksFor(120); i++) {
      e.tick();
      for (final ev in e.drainEvents()) {
        if (ev is AttackFired) fired.add(ev);
        if (ev is Kill) kills++;
      }
    }
    expect(kills, greaterThan(20));
    expect(e.state.wallet.gold > BigNum.zero, isTrue);
    expect(e.state.progress.stage, greaterThan(1));
    expect(fired, isNotEmpty);
    for (final f in fired.take(50)) {
      expect(f.fromX, isNotNull);
      expect(f.angle, closeTo(math.atan2(f.y - top.shipY, f.x - top.shipX), 1e-9));
    }
    // 사방에서 맞혔다(옆모습처럼 오른쪽만이 아님).
    final quadrants = {for (final f in fired) ((f.angle! + math.pi) / (math.pi / 2)).floor() % 4};
    expect(quadrants.length, greaterThanOrEqualTo(3));
  });

  test('결정론: 같은 시드·같은 명령이면 같은 상태', () {
    String run() {
      final e = engineOf(game(seed: 11))..advance(ticksFor(60));
      return jsonEncode(e.state.battle!.toJson());
    }

    expect(run(), run());
  });

  test('옆모습 → 탑다운 전환: SetSetting 다음 틱부터 top, 진행(스테이지·골드)은 그대로', () {
    final e = engineOf(game(view: 'side'))..advance(ticksFor(30));
    expect(e.state.battle!.mode, 'side');
    final stage = e.state.progress.stage;
    e
      ..enqueue(const SetSetting('battleView', 'top'))
      ..advance(2);
    expect(e.state.battle!.mode, 'top');
    expect(e.state.progress.stage, stage);
  });

  test('보스: 위에서 나와 standoff 원에 멈추고, 원을 벗어나지 않는다', () {
    final e = engineOf(game())
      ..enqueue(const OpSpawnBoss())
      ..tick();
    double dist() {
      final boss = e.state.battle!.enemies.firstWhere((x) => x.boss);
      return math.sqrt(math.pow(boss.x - top.shipX, 2) + math.pow(boss.y - top.shipY, 2));
    }

    final boss0 = e.state.battle!.enemies.firstWhere((x) => x.boss);
    expect(boss0.y, lessThan(top.shipY));
    var reached = false;
    for (var i = 0; i < ticksFor(25) && e.state.battle!.bossActive; i++) {
      e.tick();
      if (!e.state.battle!.enemies.any((x) => x.boss)) break;
      if (dist() <= top.bossStandoff + 1e-6) reached = true;
      // 원 안으로는 들어오지 않고, 충격·강습에 밀려도 잠깐 바깥(밀린 만큼)이다.
      if (reached) expect(dist(), inInclusiveRange(top.bossStandoff - 1e-6, top.bossStandoff + 20));
    }
    expect(reached, isTrue);
  });
}
