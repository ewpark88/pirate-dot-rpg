import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final t = GameTables.load();
  final cfg = CrewPreview.config(t);
  final phase = (cfg.number('phaseSec') * 1000 / t.waves.tickMs).round();

  test('미리보기: 그 선원 혼자 쏘고, 무리 ↔ 보스가 번갈아 나오고, 같은 선원·레벨이면 같은 기록', () {
    final a = CrewPreview(t, crewId: 'pang', level: 30);
    final b = CrewPreview(t, crewId: 'pang', level: 30);
    var fired = 0;
    var boss = false;
    var swarm = false;
    for (var i = 0; i < phase * 3; i++) {
      final x = a.step();
      final y = b.step();
      expect(x.frame.toJson(), y.frame.toJson(), reason: '틱 $i');
      for (final e in x.events) {
        if (e is AttackFired) {
          expect(e.crewId, 'pang');
          fired++;
        }
      }
      boss |= x.frame.bossActive;
      swarm |= x.frame.enemies.where((e) => !e.boss).length >= cfg.integer('swarm') ~/ 2;
      expect(x.frame.fleet.map((f) => f.crewId), ['pang']);
    }
    expect(fired, greaterThan(0));
    expect(boss, isTrue, reason: '보스 차례');
    expect(swarm, isTrue, reason: '무리 차례');
  });

  test('레벨(등급)이 다르면 기록이 다르다 — 등급 탭이 실제로 다른 장면', () {
    final low = CrewPreview(t, crewId: 'pang', level: t.rarities.rarities.first.levelMin);
    final high = CrewPreview(t, crewId: 'pang', level: t.rarities.rarities.last.levelMin);
    var differs = false;
    for (var i = 0; i < 120 && !differs; i++) {
      differs = low.step().frame.toJson().toString() != high.step().frame.toJson().toString();
    }
    expect(differs, isTrue);
  });

  test('배 고정(OpSetShipStill): 무리 차례엔 배가 순항하지 않고 가운데 그대로 — 공격 모양이 보이게(S1 2026-10-17)', () {
    final p = CrewPreview(t, crewId: 'pang', level: 30);
    final top = t.waves.raw.obj('top');
    for (var i = 0; i < phase - 1; i++) {
      final f = p.step().frame;
      expect(f.shipX ?? top.number('shipX'), top.number('shipX'), reason: '틱 $i');
      expect(f.shipY ?? top.number('shipY'), top.number('shipY'), reason: '틱 $i');
    }
    expect(Command.fromJson(const OpSetShipStill(on: true).toJson()).toJson(), const OpSetShipStill(on: true).toJson());
  });
}
