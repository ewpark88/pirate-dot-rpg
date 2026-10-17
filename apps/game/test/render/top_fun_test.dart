import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

import 'helpers.dart';

void main() {
  List<RecordedTick> rec(List<GameEvent> at10) => [
    for (var t = 0; t < 40; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(1),
          shipHpMax: BigNum.from(1),
          mode: 'top',
          enemies: const [EnemyView(id: 7, kind: 'goldfish', x: 100, y: 170, hpRatio: 1)],
        ),
        t == 10 ? at10 : const [],
      ),
  ];

  BattleScene run(List<GameEvent> e) {
    final s = BattleScene(tables, rec(e));
    while (s.player.position < 10.5) {
      s.update(10);
    }
    return s;
  }

  test('피버 시작: 금빛 번쩍, 화면 흔들기 없음(사용자 "화면이 좌우로 움직이면 조잡하다")', () {
    final s = run([const FeverStarted(10, untilTick: 100)]);
    expect(s.moments.feverFlashMs, greaterThan(0));
    expect(s.shake.peak, 0);
  });

  test('황금 물고기 잡힘: 금 숫자 + 금화가 배로(금액 그대로)', () {
    final s = run([GoldfishCaught(10, targetId: 7, gold: BigNum.from(500))]);
    expect(s.numbers.active.any((n) => n.kind == DamageKind.crit && n.amount.toDouble() == 500), isTrue);
    final coin = s.coins.active.singleWhere((c) => c.amount.toDouble() == 500);
    expect((coin.toX, coin.toY), (s.topShip.dx, s.topShip.dy));
  });

  test('무리 처치 손맛은 무리 크기 비례: 40마리면 퍼퍼펑 6번·금화 터짐 8곳·흔들림 5.2px, 5마리면 2번·2곳·1.95px', () {
    final bursts = <int, int>{};
    final shake = <int, double>{};
    BattleScene multi(int count) {
      final s = BattleScene(tables, rec([MultiKill(10, count: count)]));
      for (var i = 0; i < 12; i++) {
        s.moments.killAt(10.0 * i, 50);
      }
      while (s.player.position < 10.5) {
        s.update(10);
      }
      bursts[count] = s.effects.active.where((e) => e.sheetId == 'coin_burst').length;
      shake[count] = s.shake.peak;
      for (var i = 0; i < 40; i++) {
        s.update(10); // 연쇄 소리 45ms 간격
      }
      return s;
    }

    final big = multi(40);
    final small = multi(5);
    int pops(BattleScene s) => s.audioLog.where((id) => id == 'pop').length;
    expect((pops(big), pops(small)), (6, 2));
    expect((bursts[40], bursts[5]), (8, 2));
    expect(shake[40], closeTo(5.2, 1e-9)); // ×1.3(S1 임팩트)
    expect(shake[5], closeTo(1.95, 1e-9));
  });

  test('대군 습격(HordeIncoming): 붉은 띠 HORDE! + 마리 수 + 흔들림', () {
    final s = run([const HordeIncoming(10, stage: 5, count: 80)]);
    expect((s.moments.bannerText, s.moments.bannerSub, s.moments.bannerHot), ('HORDE!', 'x80', true));
    expect(s.shake.peak, greaterThan(0));
  });
}
