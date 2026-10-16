import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/economy/fever.dart' show feverOn, feverSupport;
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';

/// 피버 첫 일격 (사용자 결정 2026-10-17: '궁극기를 제거하고 게이지를 피버 하나로 — 궁극기 일격은 피버가 시작되는 순간의 첫 연출로').
/// 피버가 켜진 첫 틱(남은 틱이 아직 꽉 찬 틱)에 선장 계열 궁극기 효과(화면 전체 피해 + 해일 등)를 한 번. UltimateCast 이벤트 그대로(렌더 재사용).
extension FeverStrike on Round {
  void feverStrike(GameState s) {
    if (!feverOn(s)) return;
    final f = t.meta.raw.obj('fever');
    final full = ((f.number('durationSec') + feverSupport(s, t).extraSec) / (t.waves.tickMs * secondsPerMillisecond))
        .round();
    if (s.battle!.feverTicksLeft != full) return;
    castUltimate();
  }
}
