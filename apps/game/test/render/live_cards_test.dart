import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/render/battle_game.dart';

import 'helpers.dart';

/// 사용자 폰 신고(a920ed0a '카드 들어올 때 연출이 없다'): 골든은 만든 이벤트라, 실제 엔진 흐름(EngineHost 라이브)으로
/// 첫 5분 — 환영 선원(starter)·보스 카드 — 의 CardGranted가 전부 렌더 카드 연출까지 이어지는지 센다(회귀).
void main() {
  test('실제 엔진 첫 5분: CardGranted마다 카드 연출이 뜬다', () async {
    final clock = ManualClock(DateTime.utc(2026, 10, 17));
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 'test', seed: 11, now: clock.now(), crews: tables.meta.startingCrews),
      clock: clock,
    );
    final game = BattleGame(feed: host.ticks, tables: tables, loadSprites: false)
      ..onGameResize(Vector2(kLogicalWidth * 3, kLogicalHeight * 3));
    await game.onLoad();
    final granted = <CardGranted>[];
    host.ticks.listen((t) => granted.addAll(t.events.whereType<CardGranted>()));
    host
      ..send(const TutorialAck(1))
      ..send(const UpgradePart('cannon'));
    const frames = 60 * 60 * 5;
    for (var f = 0; f < frames; f++) {
      if (f % 3 == 0) {
        clock.advance(host.engine.tickLength);
        host.step();
        // 사람처럼 가끔 강화(보스를 넘어 카드를 받게)
        if (f % 600 == 0) {
          for (final p in const ['cannon', 'hull', 'sail']) {
            host.send(UpgradePart.max(p));
          }
        }
      }
      game.update(1 / 60);
    }
    expect(granted.any((g) => g.source == 'starter'), isTrue, reason: '환영 선원 카드가 나와야 한다');
    expect(granted.any((g) => g.source == 'boss'), isTrue, reason: '첫 5분에 보스 카드가 나와야 한다');
    expect(game.scene.topHits.cardsShown, granted.length, reason: '받은 카드마다 연출: ${granted.map((g) => g.source)}');
    // 초반엔 모든 등급이 앞면 공개(fx_map cardFx.minRarity 기본 common — 폰 신고 '연출이 없다').
    expect(game.scene.topHits.loot.revealFrom, 0);
    game.onRemove();
    host.stop();
  });
}
