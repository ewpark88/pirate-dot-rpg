import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' as side;
import 'package:game_core/src/battle/targeting.dart' as side;
import 'package:game_core/src/battle/targeting.dart' show Volley;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 점 하나.
typedef Point = ({double x, double y});

/// 전장의 '모양': 적이 어디서 나와 어디로 가고, 누가 사거리 안인가 (탑다운 전환 T1).
/// 피해 공식·스킬·보스 패턴·보상은 모드와 상관없이 공용 코드(combat·skills·bosses)가 그대로 하고, 위치에 관한 것만 이것에 묻는다.
/// - [SideGeometry]: 옆모습. 지금 함수(targeting·spawner)를 그대로 부른다 — 결과가 바이트 단위로 같다.
/// - TopGeometry(top_geometry.dart): 위에서 내려다본 2D, 배 중심 고정.
abstract interface class BattleGeometry {
  /// `side` | `top` (BattleView.mode).
  String get mode;

  /// 배 위치(배 대상 스킬의 연출 위치).
  Point get ship;

  /// 화면 전체 공격(궁극기·전설 화면 스킬)의 중심.
  Point get center;

  /// 보이는 화면 안인가 — 그 밖의 적은 맞히지 않는다.
  bool onScreen(Foe e);

  /// [a]가 맞힐 수 있는 적(사거리 + [reachBonus], 화면 안, 층 제외).
  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0});

  /// [n]발을 서로 다른 대상에 (맞힐 적이 적으면 있는 만큼).
  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0});

  /// 무리 한 파를 [f]에 더한다(수치는 spawner와 같고 위치만 모드마다).
  void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind});

  /// spawner.startBoss가 만든 보스·촉수를 이 모드의 자리로. 상태 불러오기면 [x]·[y]를 이어받는다.
  void placeBoss(Field f, {double? x, double? y});

  /// [e]를 한 틱 움직인다. 이미 배에 닿아 있으면(이번 틱에 공격할 수 있으면) true.
  bool advance(Foe e, double speed, double dt);

  /// 틱 끝 정리(겹침 풀기, 보스 원 돌기).
  void settle(Field f, double dt);

  /// 밀어내기(배에서 멀어지는 쪽으로 [distance]).
  void push(Foe e, double distance);

  /// 점 ([x],[y]) 쪽으로 [amount]만큼 끌어당김(음수면 밀어냄). 지나치지 않는다.
  void pull(Foe e, double x, double y, double amount);

  /// 분열한 작은 적 [n]마리 중 [i]번째 자리.
  Point splitAt(Foe parent, int i, int n);

  /// [e]가 향하는 방향(라디안, atan2(dy, dx)) — 렌더가 그림을 돌린다. 옆모습은 null(EnemyView 기본 = 왼쪽).
  double? heading(Foe e);

  /// BattleView.shipX·shipY로 낼 배 중심. 옆모습은 null(옛 기록과 같게).
  Point? get viewShip;

  /// 조준점 ([tx],[ty])으로 쏘는 포구와 방향(AttackFired.fromX·fromY·angle). 옆모습은 null.
  ({double x, double y, double angle})? muzzle(double tx, double ty);
}

/// Settings.battleView(`side` | `top`)에 맞는 전장 모양. 탑다운 배 반경은 [stage]의 배 등급(ship_tiers topRadius).
BattleGeometry geometryFor(String mode, GameTables t, int stage) =>
    mode == 'top' ? TopGeometry.of(t.waves, shipRadius: t.shipTiers.tierAt(stage).topRadius) : SideGeometry(t.waves);

/// 옆모습: 배는 왼쪽(shipX), 적은 오른쪽에서 줄지어 걸어온다. 지금 동작 그대로.
class SideGeometry implements BattleGeometry {
  SideGeometry(this.w);

  final WavesTable w;

  FieldDef get _f => w.field;

  @override
  String get mode => 'side';

  @override
  Point get ship => (x: _f.shipX, y: _f.shipY);

  @override
  Point get center => (x: _f.width * half, y: _f.shipY);

  @override
  bool onScreen(Foe e) => e.x <= _f.visibleRight;

  @override
  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0}) =>
      side.eligible(a, foes, _f, reachBonus: reachBonus);

  @override
  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0}) =>
      side.aimMany(a, n, foes, w, rng, reachBonus: reachBonus);

  @override
  void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) =>
      side.spawnWaveSide(f, stage, ctx, count: count, kind: kind);

  @override
  void placeBoss(Field f, {double? x, double? y}) {}

  @override
  bool advance(Foe e, double speed, double dt) {
    // 일반 적은 몸통이 겹치지 않게 contactGap에서, 보스는 standoff에서 멈춘다(정지 전 slowZone에서 감속).
    final stop = _f.shipX + (e.boss ? w.bossStandoff : _f.contactGap);
    if (e.x > stop) {
      final left = e.x - stop;
      final v = e.boss && left < w.bossSlowZone ? speed * math.max(left / w.bossSlowZone, w.bossSlowFloor) : speed;
      e.x = e.x - v * dt < stop ? stop : e.x - v * dt;
      return false;
    }
    return true;
  }

  @override
  void settle(Field f, double dt) {}

  @override
  void push(Foe e, double distance) => e.x = math.min(e.x + distance, _f.width);

  @override
  void pull(Foe e, double x, double y, double amount) {
    final dx = x - e.x;
    final step = math.min(dx.abs(), amount.abs());
    e.x += (amount > 0 ? dx.sign : -dx.sign) * step;
  }

  @override
  Point splitAt(Foe parent, int i, int n) => (x: parent.x + (i - (n - 1) * half) * _f.spawnSpacing, y: parent.y);

  @override
  double? heading(Foe e) => null;

  @override
  Point? get viewShip => null;

  @override
  ({double x, double y, double angle})? muzzle(double tx, double ty) => null;
}
