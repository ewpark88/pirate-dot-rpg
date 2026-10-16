import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/hp_pill.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/paint/status_painter.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 탑다운 표시들 (T4-3 — 옆모습 화가만 그리던 것을 옮김): 수중 구역, 적 상태 아이콘·보호막·정예 테두리,
/// 떠내려온 보물상자, 배 회복·강화 빛, 화면 번쩍. 그림은 전장 좌표(배 중심 원점 아님 — 부르는 쪽이 옮겨 둔다).
class TopMarks {
  TopMarks(this.scene, this.sprites) : _status = StatusPainter(scene);

  final BattleScene scene;
  final SpriteDraw sprites;
  final StatusPainter _status;
  final _fill = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke;

  late final HpPill _pill = HpPill(scene.fx.raw.obj('shipHp'));
  late final double _lagMs = scene.fx.raw.obj('shipHp').number('lagMs');
  final Map<int, double> _bossLag = {};
  double _lastMs = 0;

  late final int _zoneColor =
      ((scene.fx.zone.number('alpha') * 0xFF).round() << 24) |
      (parseArgb(scene.fx.zone.str('color'), 'zone.color') & 0xFFFFFF);
  late final int _shieldColor = parseArgb(scene.fx.shield.str('color'), 'shield.color');
  late final double _shieldPx = scene.fx.shield.number('px');
  late final int _heal = parseArgb(scene.fx.shipSkill.str('healColor'), 'shipSkill.healColor');
  late final int _buff = parseArgb(scene.fx.shipSkill.str('buffColor'), 'shipSkill.buffColor');

  /// 정예 테두리 바깥에 보호막이 오도록 띄우는 간격(단위).
  static const _shieldGap = 2.0;

  /// 수중 구역(바다 위 반투명 원) — 적 아래.
  void zones(Canvas c) {
    // 위에서 본 바다는 파래서 옆모습 색(파랑 35%)만으로는 안 보인다 — 짙은 소용돌이 + 밝은 테.
    for (final z in scene.zones.active) {
      final at = Offset(z.x.roundToDouble(), z.y.roundToDouble());
      final r = z.radius.roundToDouble();
      _fill.color = const Color(0x55082848);
      c.drawCircle(at, r, _fill);
      _fill.color = Color(_zoneColor);
      c.drawCircle(at, r * 0.6, _fill);
      _circle(c, at, r, 1, 0x99CFEFFF);
    }
  }

  /// 적 위 표시: 정예 등급 고리, 보호막 고리, 상태 아이콘(둔화·화상·기절·취약). [radiusOf]는 적 그림 반지름.
  void enemies(Canvas c, Rect cull, double Function(EnemyPose e) radiusOf) {
    final looks = scene.looks;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (e.layer == 'underwater' || !cull.contains(Offset(e.drawX, e.drawY))) continue;
      final r = radiusOf(e);
      final at = Offset(e.drawX.roundToDouble(), e.drawY.roundToDouble());
      final tier = looks.tierColor(e.tier);
      if (tier != null) _circle(c, at, r + 1, 1, tier);
      if (e.shielded) _circle(c, at, r + 1 + _shieldGap, _shieldPx, _shieldColor);
      _status.paint(c, e, e.drawY - r, e.drawY + r);
    }
  }

  /// 보스 체력 막대: 보스 위 알약형(해골 아이콘), 배 막대와 같은 3단계 색·흰 지연 조각.
  void bosses(Canvas c, double Function(EnemyPose e) radiusOf) {
    final dt = (scene.clockMs - _lastMs).clamp(0.0, 100.0);
    _lastMs = scene.clockMs;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (!e.boss) continue;
      final r = radiusOf(e);
      final ratio = e.hpRatio.clamp(0.0, 1.0);
      final prev = _bossLag[e.id] ?? ratio;
      final lag = prev < ratio ? ratio : (prev - dt / _lagMs).clamp(ratio, 1.0);
      _bossLag[e.id] = lag;
      final w = (r * 1.6).clamp(30.0, 60.0).roundToDouble() + 6;
      var fill = _pill.colorFor(ratio);
      if (_pill.isLow(ratio) && (scene.clockMs / 250).floor().isEven) {
        fill = Color.lerp(Color(fill), const Color(0xFFFFFFFF), 0.35)!.toARGB32();
      }
      _pill.paint(
        c,
        left: (e.drawX - w / 2).roundToDouble(),
        top: (e.drawY - r - 10).roundToDouble(),
        w: w,
        h: 6,
        ratio: ratio,
        lag: lag,
        fill: fill,
        skull: true,
      );
    }
    if (_bossLag.length > 8) _bossLag.clear();
  }

  /// 떠내려온 보물상자(전장 좌표). 가라앉을수록 흐려진다 — 누를 곳·남은 시간 링·금액은 UI(ChestLayer).
  void chest(Canvas c, double clockMs) {
    final ch = scene.chest;
    if (!ch.visible) return;
    sprites.draw(
      c,
      'td_event:chest',
      ch.x.roundToDouble(),
      ch.y.roundToDouble(),
      frame: (clockMs / 450).floor() % 2,
      alpha: 1 - 0.7 * ch.sink,
    );
  }

  /// 배 회복(초록 덮개)·강화(테) 빛 — 배 상자 [box](배 중심 원점).
  void shipAura(Canvas c, Rect box) {
    if (scene.shipHealMs > 0 && scene.settings.flash) {
      _fill.color = Color((0x55 << 24) | (_heal & 0xFFFFFF));
      c.drawOval(box.inflate(2), _fill);
    }
    if (scene.shipBuffMs > 0) _circle(c, box.center, box.longestSide / 2 + 3, 1, _buff, oval: box.inflate(3));
  }

  /// 화면 번쩍(궁극기·보스 처치 등) — 화면 좌표 [box] 전체.
  void screenFlash(Canvas c, Rect box) {
    if (scene.screenFlashMs <= 0 || !scene.settings.flash) return;
    _fill.color = const Color(0x99FFFFFF);
    c.drawRect(box, _fill);
  }

  void _circle(Canvas c, Offset at, double r, double px, int color, {Rect? oval}) {
    _ring
      ..color = Color(color)
      ..strokeWidth = px;
    if (oval != null) {
      c.drawOval(oval, _ring);
    } else {
      c.drawCircle(at, r, _ring);
    }
  }
}
