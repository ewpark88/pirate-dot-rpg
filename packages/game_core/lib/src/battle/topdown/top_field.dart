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
    double? bossSpawnRadius,
    this.swarmSpacing = 0,
    this.spawnWeights,
    double? viewWidth,
    double? viewHeight,
    double? hullHalfWidth,
    double? hullHalfLength,
    this.hullOffset = 0,
    this.mobSpeedScale = 1,
    this.spawnPatterns,
    this.scatterGapMin = 0,
    this.scatterGapMax = 0,
    this.arcSpreadDeg = 0,
    this.nearSpawn,
    this.standoffGrow = 0,
    this.orbitMax = double.infinity,
  }) : hullHalfWidth = hullHalfWidth ?? shipRadius,
       hullHalfLength = hullHalfLength ?? shipRadius,
       bossSpawnRadius = bossSpawnRadius ?? approachRadius,
       viewWidth = viewWidth ?? width,
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
      standoffGrow: j.has('bossScale') ? j.obj('bossScale').numberOr('standoffGrow', 0) : 0,
      orbitMax: j.has('bossScale') ? j.obj('bossScale').numberOr('orbitMax', double.infinity) : double.infinity,
      reachScale: d.reachScale,
      bossSpawnRadius: j.numberOr('bossSpawnRadius', d.approachRadius),
      swarmSpacing: j.numberOr('swarmSpacing', w.field.spawnSpacing),
      spawnWeights: j.has('spawnWeights')
          ? (
              up: j.obj('spawnWeights').number('up'),
              side: j.obj('spawnWeights').number('side'),
              down: j.obj('spawnWeights').number('down'),
            )
          : null,
      viewWidth: j.numberOr('viewWidth', d.width),
      viewHeight: j.numberOr('viewHeight', d.height),
      mobSpeedScale: j.numberOr('mobSpeedScale', 1),
      spawnPatterns: j.has('spawnPatterns')
          ? j.obj('spawnPatterns').raw.map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
      scatterGapMin: j.has('scatterGapSec') ? ((j.raw['scatterGapSec'] as List).first as num).toDouble() : 0,
      scatterGapMax: j.has('scatterGapSec') ? ((j.raw['scatterGapSec'] as List).last as num).toDouble() : 0,
      arcSpreadDeg: j.numberOr('arcSpreadDeg', 0),
      nearSpawn: j.has('nearSpawn')
          ? (
              ratio: j.obj('nearSpawn').number('ratio'),
              distanceMin: j.obj('nearSpawn').number('distanceMin'),
              distanceMax: j.obj('nearSpawn').number('distanceMax'),
              warnSec: j.obj('nearSpawn').number('warnSec'),
              midDelayMaxSec: j.obj('nearSpawn').numberOr('midDelayMaxSec', 0),
            )
          : null,
    );
  }

  /// 전장(세로). 화면보다 클 수 있다 — 바깥은 스폰 여유.
  final double width;
  final double height;

  /// 배 중심 (고정).
  final double shipX;
  final double shipY;

  /// 선체 캡슐(배 중심, 위아래 축): 반폭·반길이. 적은 이 몸통에 닿을 때까지 오고, 사거리도 몸통에서 잰다. 없으면 반경 [shipRadius]의 원.
  final double hullHalfWidth;
  final double hullHalfLength;

  /// 선체 캡슐 중심이 배 중심에서 배꼬리 쪽(+y)으로 떨어진 거리 — 선체 그림이 프레임 가운데보다 뒤로 치우쳐 있다.
  final double hullOffset;

  /// 스폰 패턴 가중(swarm·scatter·arc, waves.top.spawnPatterns). null이면 늘 swarm.
  final Map<String, double>? spawnPatterns;

  /// scatter 패턴: 1~2마리씩 나오는 간격(초) 범위.
  final double scatterGapMin;
  final double scatterGapMax;

  /// arc 패턴: 반원 대열의 퍼짐(도).
  final double arcSpreadDeg;

  /// 배 위협 (b) 가까이 등장(waves.top.nearSpawn, 선택): 한 파의 ratio만큼을 배 몸통에서 distanceMin~Max 자리에,
  /// warnSec 예고 뒤 솟아오르게. 절반은 파 도중(0~midDelayMaxSec 뒤). null이면 없음.
  final ({double ratio, double distanceMin, double distanceMax, double warnSec, double midDelayMaxSec})? nearSpawn;

  /// 잡몹 이동 속도 배율(탑다운 화면에서 배까지 몇 초 안에 닿게, 사용자 신고 2026-10-15 '멈춰 있는 것 같다'). 보스는 그대로.
  final double mobSpeedScale;

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

  /// 보스가 출발하는 원(배 중심 기준, 보스 가장자리가 이 원 바로 밖) — 기본은 접근 원. 빠른 항해의 보스 간격을 옆모습과 맞춘다(S2 결정 ①).
  final double bossSpawnRadius;

  /// 한 묶음 안 k번째 적이 k × 이만큼 더 바깥에서 출발(줄 간격). 옆모습 spawnSpacing보다 촘촘하게 — 많은 무리가 늦게 닿지 않게.
  final double swarmSpacing;

  /// 묶음 방향 가중: 위·좌우(한쪽마다)·아래. 배가 화면 아래쪽에 있으면 위에서 더 많이(S3 카메라). null이면 모든 방향 같게.
  final ({double up, double side, double down})? spawnWeights;

  /// 보스가 멈춰 도는 원의 반지름(배 중심 기준)과 도는 속도.
  final double bossStandoff;
  final double bossOrbitDegPerSec;

  /// 큰 보스(Foe.scale > 1): standoff가 늘어난 반경 × 이만큼 더 멀어진다(그림이 배와 겹치지 않게) · 배율이 [orbitMax]를 넘으면
  /// 원을 돌지 않고 배 위쪽에 선다(대보스 그림이 화면 폭에 가까워 옆으로 돌면 화면 밖으로 나간다). waves.top.bossScale.
  final double standoffGrow;
  final double orbitMax;

  /// 사거리 배율 (skills.json reach × 이 값).
  final double reachScale;

  /// 카메라가 보이는 사각형(배 중심 기준 가운데). 이 밖의 적은 맞히지 않는다(옆모습 visibleRight와 같은 뜻).
  final double viewWidth;
  final double viewHeight;

  /// 배 반경·선체 캡슐을 바꾼 사본(null이면 그대로).
  TopField withShipRadius(double? r, {double? halfWidth, double? halfLength, double offset = 0}) => r == null
      ? this
      : _copy(shipX: shipX, shipY: shipY, r: r, halfWidth: halfWidth ?? r, halfLength: halfLength ?? r, offset: offset);

  /// 배 중심만 옮긴 사본(피버 좌우·앞뒤 이동 — meta.fever.weave).
  TopField withShipAt(double x, double y) => _copy(
    shipX: x,
    shipY: y,
    r: shipRadius,
    halfWidth: hullHalfWidth,
    halfLength: hullHalfLength,
    offset: hullOffset,
  );

  TopField _copy({
    required double shipX,
    required double shipY,
    required double r,
    required double halfWidth,
    required double halfLength,
    required double offset,
  }) => TopField(
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
    standoffGrow: standoffGrow,
    orbitMax: orbitMax,
    reachScale: reachScale,
    bossSpawnRadius: bossSpawnRadius,
    swarmSpacing: swarmSpacing,
    spawnWeights: spawnWeights,
    viewWidth: viewWidth,
    viewHeight: viewHeight,
    hullHalfWidth: halfWidth,
    hullHalfLength: halfLength,
    hullOffset: offset,
    mobSpeedScale: mobSpeedScale,
    spawnPatterns: spawnPatterns,
    scatterGapMin: scatterGapMin,
    scatterGapMax: scatterGapMax,
    arcSpreadDeg: arcSpreadDeg,
    nearSpawn: nearSpawn,
  );

  /// [e]의 원 반지름(보스는 크기 배율만큼).
  double radiusOf(Foe e) => e.boss ? bossRadius * e.scale : mobRadius;

  /// [e]가 서는 원의 반지름(배 중심 기준). 큰 보스는 늘어난 반경 × standoffGrow만큼 멀리.
  double standoffOf(Foe e) => bossStandoff + (e.boss ? bossRadius * (e.scale - 1) * standoffGrow : 0);

  /// 큰 보스 가장자리가 멀어진 만큼(standoff 증가 − 반경 증가) — 보스 사거리(bossReach)에 더해 닿는 거리를 그대로 둔다.
  double reachExtraOf(Foe e) => standoffOf(e) - bossStandoff - (radiusOf(e) - (e.boss ? bossRadius : mobRadius));

  /// 원을 도는가(배율이 orbitMax 이하).
  bool orbits(Foe e) => e.scale <= orbitMax;
}
