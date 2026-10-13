import 'package:game_core/game_core.dart';

/// 렌더 레인용 손으로 짠 전투 기록 (4초, 80틱). 전투 레인이 BattleSystem을 구현하면
/// `game_cli export-events`가 실제 엔진 출력으로 이 파일을 대체한다.
///
/// 장면: 무리 8마리 접근 → 옥토(곡사) 범위 폭발로 3마리 동시 처치(트리플) →
/// 팡(직사) 치명타 → 핀(관통) 한 줄 관통 → 함성 게이지 가득 → 해일 궁극기로 정리.
List<RecordedTick> syntheticBattle() {
  const fleet = ['octo', 'pang', 'sword'];
  final hp = <int, double>{for (var i = 1; i <= 8; i++) i: 1};
  final alive = <int>{for (var i = 1; i <= 8; i++) i};
  final out = <RecordedTick>[];

  double xOf(int id, int tick) => 300 - tick * 1.6 + (id % 4) * 14;
  double yOf(int id) => 36.0 + (id % 4) * 22 + (id ~/ 4) * 10;
  const kinds = ['crab', 'jelly', 'fish', 'puffer', 'gull', 'urchin', 'crab', 'jelly'];

  for (var t = 0; t < 80; t++) {
    final ev = <GameEvent>[];
    void hit(int id, num dmg, {bool crit = false, String crew = 'octo'}) {
      hp[id] = (hp[id]! - dmg / 100).clamp(0, 1);
      ev.add(Damage(t, targetId: id, amount: BigNum.from(dmg), crit: crit, crewId: crew));
      if (hp[id] == 0 && alive.remove(id)) {
        ev.add(Kill(t, targetId: id, gold: BigNum.from(12), x: xOf(id, t), y: yOf(id)));
      }
    }

    switch (t) {
      case 20:
        ev.add(AttackFired(t, crewId: 'octo', family: 'lob', targetIds: const [1, 2, 5, 6], x: xOf(1, t), y: yOf(1)));
      case 24:
        for (final id in [1, 2, 5]) {
          hit(id, 120);
        }
        hit(6, 60);
        ev
          ..add(AoeDamageSum(t, total: BigNum.from(420), x: xOf(1, t), y: yOf(1)))
          ..add(MultiKill(t, count: 3));
      case 30:
        ev.add(AttackFired(t, crewId: 'pang', family: 'direct', targetIds: const [6], x: xOf(6, t), y: yOf(6)));
        hit(6, 80, crit: true, crew: 'pang');
        ev.add(HitStop(t, ticks: 1, reason: 'crit'));
      case 40:
        ev.add(AttackFired(t, crewId: 'sword', family: 'pierce', targetIds: const [3, 7], x: 320, y: yOf(3)));
        hit(3, 70, crew: 'sword');
        hit(7, 63, crew: 'sword');
      case 55:
        ev
          ..add(UltimateCast(t, crewId: 'octo', ultimateId: 'ult_tidal_wave'))
          ..add(HitStop(t, ticks: 2, reason: 'ultimate'));
        for (final id in alive.toList()) {
          hit(id, 150);
        }
        ev.add(MultiKill(t, count: 4));
      case 70:
        ev.add(WaveCleared(t, wave: 1));
    }

    out.add(
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(60),
          shipHpMax: BigNum.from(60),
          enemies: [
            for (final id in alive)
              EnemyView(
                id: id,
                kind: kinds[id - 1],
                x: xOf(id, t),
                y: yOf(id),
                hpRatio: hp[id]!,
                layer: _layers[kinds[id - 1]] ?? 'surface',
              ),
          ],
          fleet: [for (final c in fleet) FleetSlot(crewId: c, cooldown: (t % 20) / 20)],
          captainId: 'octo',
        ),
        ev,
      ),
    );
  }
  return out;
}

const _layers = {'gull': 'air', 'jelly': 'underwater', 'fish': 'underwater', 'urchin': 'underwater'};
