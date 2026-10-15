import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

/// 지루함 해소 3종 계약 (sea-events 4절, fever 계약): 명령 2·이벤트 10·BattleView·Progress 선택 키.
void main() {
  test('명령 JSON 왕복', () {
    for (final c in const <Command>[TapSeaEvent(17), PickBottle(2)]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson(), reason: c.type);
    }
  });

  test('이벤트 JSON 왕복 (auto·reward는 선택)', () {
    final events = <GameEvent>[
      const SeaEventStarted(1, id: 'merchant', untilTick: 400),
      const SeaEventEnded(1, id: 'merchant', result: 'left'),
      GoldfishCaught(1, targetId: 9, gold: BigNum.parse('1.5e4')),
      GoldfishCaught(1, targetId: 10, gold: BigNum.from(7), auto: true),
      const BottleOpened(1, choices: ['gold', 'tailwind', 'gift']),
      const BottlePicked(1, index: 1, reward: 'tailwind:600'),
      const FeverStarted(1, untilTick: 200),
      const FeverEnded(1),
      const ChallengeStarted(1, id: 'kills', target: 50, untilTick: 600),
      const ChallengeProgress(1, id: 'kills', value: 37),
      const ChallengeEnded(1, id: 'kills', success: true, reward: 'gold:3e5'),
      const ChallengeEnded(1, id: 'noHit', success: false),
    ];
    for (final e in events) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson(), reason: e.type);
    }
  });

  test('BattleView: 기본이면 키 없음, 값이 있으면 왕복 · EnemyView.eventKind', () {
    expect(BattleView.empty.toJson().keys, isNot(containsAll(['fever', 'seaEvent', 'challenge', 'feverTicksLeft'])));
    const v = BattleView(
      shipHp: BigNum.one,
      shipHpMax: BigNum.one,
      fever: 0.4,
      feverTicksLeft: 12,
      seaEvent: SeaEventView(id: 'bottle', ticksLeft: 100, choices: ['gold', 'tailwind', 'gift']),
      challenge: ChallengeView(id: 'kills', target: 50, value: 3, ticksLeft: 500),
      enemies: [EnemyView(id: 1, kind: 'merchant_ship', x: 1, y: 2, hpRatio: 1, eventKind: 'merchant')],
    );
    final back = BattleView.fromJson(v.toJson());
    expect(
      [back.fever, back.feverTicksLeft, back.seaEvent!.choices, back.challenge!.value],
      [
        0.4,
        12,
        ['gold', 'tailwind', 'gift'],
        3,
      ],
    );
    expect(back.enemies.single.eventKind, 'merchant');
    expect(v.copyWith(clearSeaEvent: true, clearChallenge: true).seaEvent, isNull);
  });

  test('Progress 선택 키: 피버 게이지·다음 돌발 이벤트(남은 초·마지막)·다음 도전 — 기본이면 본문에 없음', () {
    expect(const Progress().toJson().keys, isNot(containsAll(['fever', 'seaEvents', 'challengeInSec'])));
    const p = Progress(fever: 0.3, seaEventInSec: 45, seaEventLast: 'storm', challengeInSec: 200);
    final back = Progress.fromJson(p.toJson());
    expect([back.fever, back.seaEventInSec, back.seaEventLast, back.challengeInSec], [0.3, 45, 'storm', 200]);
  });
}
