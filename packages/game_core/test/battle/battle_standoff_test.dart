import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스는 배와 거리를 두고 멈춰 원거리로 싸운다, 일반 적은 몸통이 겹치지 않는 거리에서 멈춘다 (사용자 신고 2026-10-15).
void main() {
  final t = GameTables.load();
  final w = t.waves;
  final f = w.field;
  final start = DateTime.utc(2026, 11);

  CoreEngine engine({Map<String, int> parts = const {}}) => CoreEngine(
    tables: t,
    clock: ManualClock(start),
    initial: GameState.newGame(playerId: 's', seed: 2, now: start).copyWith(
      settings: const Settings(battleView: 'side'), // 옆모습 전용 — T4-2(SideGeometry 삭제)에서 지우거나 탑다운으로
      progress: const Progress(stage: 40, bestStage: 40),
      ship: ShipState(parts: {'hull': 200, ...parts}),
    ),
  );

  test('보스 정지 x = 뱃머리 + standoff, 보이는 화면 안, 등장 속도 20 이하', () {
    expect(f.shipX + w.bossStandoff, lessThan(f.visibleRight));
    expect(w.bossStandoff, inInclusiveRange(110, 130));
    expect(w.bossSpeed, lessThanOrEqualTo(20));
  });

  test('보스는 정지 x를 넘지 않고(30초 내내), 멈춘 뒤 원거리 공격 BossFired + ShipDamaged', () {
    final e = engine()
      ..enqueue(const OpSetInvincible(on: false))
      ..enqueue(const OpSpawnBoss());
    var fired = 0;
    var damaged = 0;
    for (var i = 0; i < w.bossTimeLimitSec * 1000 ~/ w.tickMs; i++) {
      e.tick();
      final boss = e.state.battle!.enemies.where((x) => x.boss).firstOrNull;
      if (boss != null) expect(boss.x, greaterThanOrEqualTo(f.shipX + w.bossStandoff - 1e-9));
      for (final ev in e.drainEvents()) {
        if (ev is BossFired) {
          fired++;
          expect(ev.x, closeTo(f.shipX + w.bossStandoff, 1e-6));
        }
        if (ev is ShipDamaged) damaged++;
      }
    }
    expect(fired, greaterThan(0));
    expect(damaged, greaterThanOrEqualTo(fired));
  });

  test('일반 적은 뱃머리 + contactGap에서 멈춘다 (배와 겹치지 않음)', () {
    final e = engine()..enqueue(const OpSetWave(count: 3, enemyKind: 'crab'));
    for (var i = 0; i < 40 * 1000 ~/ w.tickMs; i++) {
      e.tick();
      for (final x in e.state.battle!.enemies) {
        expect(x.x, greaterThanOrEqualTo(f.shipX + f.contactGap - 1e-9));
      }
    }
  });

  test('근접 계열(강습·충격)도 멈춘 보스를 맞힌다 — 사거리 ≥ standoff', () {
    for (final id in ['assault', 'shock']) {
      final fam = t.skills.byId(id);
      final minBonus = t.crews.crews
          .where((c) => c.family == id)
          .map((c) => c.reachBonus)
          .reduce((a, b) => a < b ? a : b);
      expect(fam.attack.raw.number('reach') + minBonus, greaterThanOrEqualTo(w.bossStandoff), reason: id);
    }
  });

  test('BossFired JSON 왕복', () {
    const ev = BossFired(5, x: 196, y: 100);
    expect(GameEvent.fromJson(ev.toJson()).toJson(), ev.toJson());
  });
}
