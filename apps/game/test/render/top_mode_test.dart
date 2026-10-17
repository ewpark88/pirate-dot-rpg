import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

import 'helpers.dart';
import 'top_recording.dart';

void main() {
  final rec = topRecording(stillTables); // 배 고정(순항 끔) — 발사체·코인이 배에서·배로

  test('T1 엔진 탑다운 기록: mode top, 적은 사방에서, 발사가 있다', () {
    expect(rec.last.frame.mode, 'top');
    expect(rec.expand((t) => t.events).whereType<AttackFired>(), isNotEmpty);
  });

  test('탑다운 장면: 발사체는 배(포구)에서 출발, 코인은 배로, 적 방향이 포즈에 실린다', () {
    final s = BattleScene(stillTables, rec);
    var launched = 0;
    var headed = 0;
    for (var f = 0; f < rec.length * 3; f++) {
      s.update(1000 / 60);
      final ship = s.topShip; // 지금 배 자리(보스 결투 비켜서기 등으로 움직인다 — 화면 밀도로 녹화에 보스전이 들어옴)
      for (final p in s.projectiles.active) {
        if (p.progress > 0 && p.progress < 0.05) {
          launched++;
          expect((Offset(p.fromX, p.fromY) - ship).distance, lessThan(60), reason: '배 근처에서 출발');
        }
      }
      for (final c in s.coins.active) {
        expect((Offset(c.toX, c.toY) - ship).distance, lessThan(30), reason: '코인은 배로(날아가는 사이 배가 조금 움직일 수 있음)');
      }
      headed += s.poses.where((e) => e.heading != 0).length;
    }
    expect(launched, greaterThan(0));
    expect(headed, greaterThan(0));
  });
}
