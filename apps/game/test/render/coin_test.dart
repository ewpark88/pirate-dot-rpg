import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

/// 사용자 지시 '돈이 금색 점처럼 들어와 모르겠다': 큰 금화가 상단 바 골드로 날아가 도착하면 UI에 금액을 알린다.
List<RecordedTick> _kills(int n, {int at = 20, int gold = 7}) => [
  for (var t = 0; t < at + 40; t++)
    tickOf(
      t,
      enemies: [for (var i = 0; i < n; i++) (i + 1, 200.0 + i)],
      events: t == at
          ? [for (var i = 0; i < n; i++) Kill(t, targetId: i + 1, gold: BigNum.from(gold), x: 200.0 + i, y: 110)]
          : const [],
    ),
];

void main() {
  final juice = tables.juice;

  test('처치마다 금화가 그 처치 골드를 싣고, UI 목표(상자 위)로 날아가 도착하면 금액을 한 번 알린다', () {
    final got = <double>[];
    final s = BattleScene(tables, _kills(1), loop: false)
      ..layout = battleFrameFor(const Size(384, 349), 2.8125)
      ..coinFlow.goldTargetDp = const Offset(40, -24)
      ..coinFlow.onCoinArrive = (a) => got.add(a.toDouble());
    while (s.coins.active.isEmpty) {
      s.update(kFrameMs);
    }
    final coin = s.coins.active.single;
    expect(coin.amount.toDouble(), 7);
    expect(coin.toY, lessThan(s.layout.viewDots.top + 1), reason: '상단 바 쪽(상자 맨 위)');
    var minY = coin.y;
    for (var i = 0; i < 120 && s.coins.active.isNotEmpty; i++) {
      s.update(kFrameMs);
      if (s.coins.active.isNotEmpty) minY = s.coins.active.single.y < minY ? s.coins.active.single.y : minY;
    }
    expect(s.coins.active, isEmpty);
    expect(got, [7], reason: '도착 한 번, 금액 그대로');
    expect(minY, lessThan(110 - 20), reason: '크게 튀어 오른다');
  });

  test('UI 목표가 없으면 예전처럼 배로', () {
    final s = BattleScene(tables, _kills(1), loop: false);
    while (s.coins.active.isEmpty) {
      s.update(kFrameMs);
    }
    expect((s.coins.active.single.toX, s.coins.active.single.toY), (kCoinTargetX, kCoinTargetY));
  });

  test('동시 상한을 넘는 처치는 마지막 금화에 더한다 — 금화 수는 상한, 합계는 그대로', () {
    final n = juice.maxCoins + 10;
    var total = 0.0;
    final s = BattleScene(tables, _kills(n), loop: false)..coinFlow.onCoinArrive = (a) => total += a.toDouble();
    while (s.coins.active.isEmpty) {
      s.update(kFrameMs);
    }
    expect(s.coins.active.length, juice.maxCoins);
    for (var i = 0; i < 200; i++) {
      s.update(kFrameMs);
    }
    expect(total, closeTo(n * 7, 1e-6));
  });
}
