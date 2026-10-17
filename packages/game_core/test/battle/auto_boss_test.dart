import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:test/test.dart';

import 'family_tables.dart';

/// 자동 보스 도전(설정 autoBoss — S3·S4 첫 15분 점검, S1 규칙): 실패 뒤 쿨다운 + 강화로 세졌으면 바로, 아니면 쿨다운 2배에 재도전.
void main() {
  final t = familyTables();
  final a = t.waves.raw.obj('boss').obj('autoBoss');
  final cool = (a.number('cooldownSec') * Duration.millisecondsPerSecond / t.waves.tickMs).round();

  GameState farming({bool auto = true, int? tutorialStep, int cannon = 3}) {
    final s = GameState.newGame(playerId: 't', seed: 1, now: DateTime.utc(2026, 11));
    return s.copyWith(
      progress: s.progress.copyWith(stage: 8, farming: true),
      settings: Settings(autoBoss: auto),
      tutorialStep: tutorialStep,
      ship: s.ship.copyWith(parts: {...s.ship.parts, 'cannon': cannon}),
    );
  }

  Field field() => Field(stage: 8, shipHpMax: BigNum.one, shipHp: BigNum.one);

  /// 틱마다 부르고 farming이 풀린 틱 수(못 풀리면 null). [upgradeAt] 틱에 대포 +1.
  int? ticksUntilBoss(GameState s0, {int? upgradeAt, int limit = 0}) {
    final f = field();
    var s = s0;
    for (var i = 1; i <= (limit == 0 ? cool * 3 : limit); i++) {
      if (i == upgradeAt) s = s.copyWith(ship: s.ship.copyWith(parts: {...s.ship.parts, 'cannon': 4}));
      s = autoBossTick(s, f, t);
      if (!s.progress.farming) return i;
      expect(f.autoBossLeft, greaterThan(0));
    }
    return null;
  }

  test('강화 없이 버티면 쿨다운 2배에, 그사이 강화하면 쿨다운에 재도전', () {
    expect(ticksUntilBoss(farming()), cool + cool);
    expect(ticksUntilBoss(farming(), upgradeAt: 10), cool);
    expect(ticksUntilBoss(farming(), upgradeAt: cool + 10), cool + 10, reason: '쿨다운 뒤 강화하면 그 틱에 바로');
  });

  test('피버 중엔 쿨다운이 멈춘다(피버 무리 손맛을 끊지 않게)', () {
    final s = farming().copyWith(
      battle: const BattleView(shipHp: BigNum.one, shipHpMax: BigNum.one, feverTicksLeft: 100),
    );
    expect(ticksUntilBoss(s), isNull);
  });

  test('튜토리얼 보스 단계에서도 재도전한다(방치 플레이어가 멈추지 않게)', () {
    final tut = t.meta.raw.obj('tutorial').obj('steps').integer('boss');
    expect(ticksUntilBoss(farming(tutorialStep: tut)), cool + cool);
  });

  test('꺼져 있으면 계속 파밍(남은 틱 0)', () {
    for (final s0 in [farming(auto: false)]) {
      final f = field();
      var s = s0;
      for (var i = 0; i < cool * 3; i++) {
        s = autoBossTick(s, f, t);
      }
      expect(s.progress.farming, isTrue);
      expect(f.autoBossLeft, 0);
    }
  });
}
