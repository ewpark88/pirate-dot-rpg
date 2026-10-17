import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 스토어 스크린샷 2차(docs/store/store-shots-v2.md 1~4번 전투 장면) 렌더 쪽 도우미 — S5 store_shot_kit이 쓴다.
/// 렌더 연출의 길이로 '화면이 가장 꽉 찬 순간'을 틱으로 바꿔 주고, 캡션을 얹어도 연출을 가리지 않는 자리를 알려 준다.
/// 길이는 렌더 코드의 값과 같다(바뀌면 여기도): 대군 띠 1.5초 · 필살기 1.1초(컷인 0.9초) · 보스 등장 대보스 1.2초.
class StoreScenes {
  StoreScenes(this.tables);

  final GameTables tables;

  int _ticks(double ms) => (ms / tables.waves.tickMs).ceil();

  /// ① 대군 습격: HordeIncoming 뒤 이 범위(틱)에서 화면 안 적이 가장 많은 순간 — 'HORDE!' 띠가 아직 떠 있는 동안.
  (int, int) get hordeWindow => (_ticks(300), _ticks(1300));

  /// ② 필살기: UltimateCast 뒤 계열 필살기가 화면을 가장 크게 덮은 때(0.45초 — 낙뢰·폭격이 절반쯤 터짐, 컷인도 남음).
  int get ultimatePeak => _ticks(450);

  /// ③ 보스 등장: BossSpawned 뒤 솟아오름이 끝나고 WARNING 띠가 사라진 첫 틱(보스가 원래 크기·체력 층 막대가 보임).
  /// 띠를 함께 찍고 싶으면 [bossWarningPeak].
  int get bossSettled => _ticks(1250);
  int get bossWarningPeak => _ticks(700);

  /// 캡션을 얹어도 되는 자리(상자 dp 기준): 위 HUD 띠 아래 ~ 보스 등장 WARNING 띠 위가 겹치므로, 캡션은 아래 선원 줄 바로 위
  /// 띠(상자 높이 72~84% — 배 아래 항적 자리)에 둔다. [box] = 전장 상자 크기.
  Rect captionRect(Size box) => Rect.fromLTRB(box.width * 0.06, box.height * 0.72, box.width * 0.94, box.height * 0.84);

  /// 그 장면이 '꽉 찼나' 빠르게 볼 때: 기록 [frame]의 화면 안(배 기준 가로 ±halfW·세로 ±halfH) 적 수.
  int onScreen(BattleView frame) {
    final top = tables.waves.raw.obj('top');
    final halfW = top.number('viewWidth') / 2;
    final halfH = top.number('viewHeight') / 2;
    final sx = frame.shipX ?? top.number('shipX');
    final sy = frame.shipY ?? top.number('shipY');
    return frame.enemies.where((e) => (e.x - sx).abs() <= halfW && (e.y - sy).abs() <= halfH).length;
  }
}
