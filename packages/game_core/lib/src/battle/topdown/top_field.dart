import 'package:game_core/src/battle/field.dart';
import 'package:game_data/game_data.dart' show WavesTable;

/// 탑다운 전장 수치 (waves.json `top`, 계약 T0 — docs/contracts/requests/platform-topdown-t0.md).
/// 좌표는 왼쪽 위 (0,0), 배 중심 (shipX, shipY) 고정. 거리는 '배 둘레 → 적 가장자리'로 잰다.
class TopField {
  const TopField({
    required this.width,
    required this.height,
    required this.shipX,
    required this.shipY,
    required this.shipRadius,
    required this.mobRadius,
    required this.bossRadius,
    required this.spawnMargin,
    required this.approachRadius,
    required this.approachBoost,
    required this.swarmGroupsMin,
    required this.swarmGroupsMax,
    required this.swarmSpreadDeg,
    required this.separation,
    required this.bossStandoff,
    required this.bossOrbitDegPerSec,
    required this.reachScale,
    double? viewWidth,
    double? viewHeight,
  }) : viewWidth = viewWidth ?? width,
       viewHeight = viewHeight ?? height;

  /// `waves.json`의 `top` 절(TopFieldDef, 계약 T0). 아직 표에 없는 값(겹침 풀기·보스 원 속도·카메라 사각형)은 선택 키.
  factory TopField.of(WavesTable w) {
    final d = w.top;
    final j = w.raw.obj('top');
    return TopField(
      width: d.width,
      height: d.height,
      shipX: d.shipX,
      shipY: d.shipY,
      shipRadius: d.shipRadius,
      mobRadius: d.mobRadius,
      bossRadius: d.bossRadius,
      spawnMargin: d.spawnMargin,
      approachRadius: d.approachRadius,
      approachBoost: d.approachBoost,
      swarmGroupsMin: d.swarmGroupsMin,
      swarmGroupsMax: d.swarmGroupsMax,
      swarmSpreadDeg: d.swarmSpreadDeg,
      separation: j.numberOr('separation', 1),
      bossStandoff: d.bossStandoff,
      bossOrbitDegPerSec: j.numberOr('bossOrbitDegPerSec', 0),
      reachScale: d.reachScale,
      viewWidth: j.numberOr('viewWidth', d.width),
      viewHeight: j.numberOr('viewHeight', d.height),
    );
  }

  /// 전장(세로). 화면보다 클 수 있다 — 바깥은 스폰 여유.
  final double width;
  final double height;

  /// 배 중심 (고정).
  final double shipX;
  final double shipY;

  /// 배·적 크기(원). 사거리와 접촉은 둘레끼리 잰다.
  final double shipRadius;
  final double mobRadius;
  final double bossRadius;

  /// 적이 나오는 곳: 보이는 테두리에서 이만큼 바깥.
  final double spawnMargin;

  /// 이 원(배 중심 기준) 밖에서는 [approachBoost]배로 다가온다 — 어느 방향에서 나와도 옆모습과 같은 시간에 닿게.
  final double approachRadius;
  final double approachBoost;

  /// 한 파를 나누는 방향 묶음 수 범위와 묶음의 퍼짐(도).
  final int swarmGroupsMin;
  final int swarmGroupsMax;
  final double swarmSpreadDeg;

  /// 겹친 적을 한 틱에 밀어내는 비율(0~1).
  final double separation;

  /// 보스가 멈춰 도는 원의 반지름(배 중심 기준)과 도는 속도.
  final double bossStandoff;
  final double bossOrbitDegPerSec;

  /// 사거리 배율 (skills.json reach × 이 값).
  final double reachScale;

  /// 카메라가 보이는 사각형(배 중심 기준 가운데). 이 밖의 적은 맞히지 않는다(옆모습 visibleRight와 같은 뜻).
  final double viewWidth;
  final double viewHeight;

  /// 배 반경만 바꾼 사본([r]이 null이면 그대로).
  TopField withShipRadius(double? r) => r == null
      ? this
      : TopField(
          width: width,
          height: height,
          shipX: shipX,
          shipY: shipY,
          shipRadius: r,
          mobRadius: mobRadius,
          bossRadius: bossRadius,
          spawnMargin: spawnMargin,
          approachRadius: approachRadius,
          approachBoost: approachBoost,
          swarmGroupsMin: swarmGroupsMin,
          swarmGroupsMax: swarmGroupsMax,
          swarmSpreadDeg: swarmSpreadDeg,
          separation: separation,
          bossStandoff: bossStandoff,
          bossOrbitDegPerSec: bossOrbitDegPerSec,
          reachScale: reachScale,
          viewWidth: viewWidth,
          viewHeight: viewHeight,
        );

  /// [e]의 원 반지름.
  double radiusOf(Foe e) => e.boss ? bossRadius : mobRadius;
}
