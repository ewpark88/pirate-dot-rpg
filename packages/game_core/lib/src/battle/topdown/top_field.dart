import 'package:game_core/src/battle/field.dart';
import 'package:game_data/game_data.dart';

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
  });

  /// `waves.json`의 `top` 절. 키가 없으면 테이블 오류(TableFormatException).
  factory TopField.of(WavesTable w) {
    final j = w.raw.obj('top');
    final groups = j.numbers('swarmGroups');
    return TopField(
      width: j.number('width'),
      height: j.number('height'),
      shipX: j.number('shipX'),
      shipY: j.number('shipY'),
      shipRadius: j.number('shipRadius'),
      mobRadius: j.number('mobRadius'),
      bossRadius: j.number('bossRadius'),
      spawnMargin: j.number('spawnMargin'),
      approachRadius: j.number('approachRadius'),
      approachBoost: j.number('approachBoost'),
      swarmGroupsMin: groups.first.toInt(),
      swarmGroupsMax: groups.last.toInt(),
      swarmSpreadDeg: j.number('swarmSpreadDeg'),
      separation: j.number('separation'),
      bossStandoff: j.number('bossStandoff'),
      bossOrbitDegPerSec: j.number('bossOrbitDegPerSec'),
      reachScale: j.numberOr('reachScale', 1),
    );
  }

  /// 보이는 전장(세로). 이 밖의 적은 맞히지 않는다.
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

  /// [e]의 원 반지름.
  double radiusOf(Foe e) => e.boss ? bossRadius : mobRadius;
}

extension on JsonReader {
  /// `[min, max]` 숫자 배열.
  List<num> numbers(String key) => (raw[key] as List).cast<num>();
}
