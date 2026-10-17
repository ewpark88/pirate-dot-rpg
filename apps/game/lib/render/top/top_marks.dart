import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/hp_pill.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/top/top_chest.dart';
import 'package:pirate_dot/render/top/top_status.dart';

/// 탑다운 표시들 (T4-3 — 옆모습 화가만 그리던 것을 옮김): 수중 구역, 적 상태 아이콘·보호막·정예 테두리,
/// 떠내려온 보물상자, 배 회복·강화 빛, 화면 번쩍. 그림은 전장 좌표(배 중심 원점 아님 — 부르는 쪽이 옮겨 둔다).
class TopMarks {
  TopMarks(this.scene, this.sprites) : _status = TopStatus(scene);

  final BattleScene scene;
  final SpriteDraw sprites;
  final TopStatus _status;
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

  final _swirl = Path();

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
      // 소용돌이 팔 3개(천천히 돎) + 가장자리 빛 맥박 (임팩트 v2)
      final spin = scene.clockMs / 600;
      for (var k = 0; k < 3; k++) {
        final a0 = spin + k * 2 * math.pi / 3;
        _swirl.reset();
        for (var s = 0; s <= 8; s++) {
          final f = s / 8;
          final a = a0 + f * 2.2;
          final p = at + Offset(math.cos(a), math.sin(a)) * (r * (0.15 + 0.75 * f));
          s == 0 ? _swirl.moveTo(p.dx, p.dy) : _swirl.lineTo(p.dx, p.dy);
        }
        _ring
          ..strokeWidth = 1.5
          ..color = const Color(0x88E6F6FF);
        c.drawPath(_swirl, _ring);
      }
      final glow = 0.5 + 0.5 * math.sin(scene.clockMs / 180);
      _circle(c, at, r + 1, 2, (((0x40 + 0x60 * glow).round()) << 24) | 0x7FD8FF);
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
      if (e.vanguard) _vanguard(c, e, at, r);
      final tier = looks.tierColor(e.tier);
      if (tier != null) _circle(c, at, r + 1, 1, tier);
      if (e.shielded) _circle(c, at, r + 1 + _shieldGap, _shieldPx, _shieldColor);
      _status.paint(c, e, r);
    }
  }

  /// 돌격대: 붉은 테(맥박) + 뒤로 길게 물보라 꼬리 + 붉은 잔상 2겹 (사용자 '무리 사이를 뚫고 와서 박는 놈이 구분되게', S5).
  void _vanguard(Canvas c, EnemyPose e, Offset at, double r) {
    final now = scene.clockMs;
    final back = Offset(-math.cos(e.heading), -math.sin(e.heading));
    for (var k = 1; k <= 6; k++) {
      final p = at + back * (r + k * 3.2) + Offset(-back.dy, back.dx) * (k.isEven ? 1.5 : -1.5);
      _fill.color = const Color(0xFFF2FBFF).withValues(alpha: 0.75 * (1 - k / 7));
      c.drawRect(Rect.fromCenter(center: p, width: 2.5 - k * 0.2, height: 2.5 - k * 0.2), _fill);
    }
    for (var k = 1; k <= 2; k++) {
      _fill.color = const Color(0xFFE8443A).withValues(alpha: 0.25 / k);
      c.drawCircle(at + back * (k * 4.0), r * 0.8, _fill);
    }
    final pulse = 0.5 + 0.5 * math.sin(now / 90 + e.id);
    _circle(c, at, r + 2, 2, (((0x99 + 0x66 * pulse).round()) << 24) | 0xE8443A);
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
  void chest(Canvas c, double clockMs) =>
      _chest.paint(c, sprites, scene.chest, clockMs, lite: scene.topHits.lite || scene.settings.powerSave);
  final _chest = TopChest();

  /// 배 회복(초록 덮개)·강화(테) 빛 — 배 상자 [box](배 중심 원점).
  void shipAura(Canvas c, Rect box) {
    if (scene.shipFlashMs > 0) {
      _fill.color = const Color(0x33FF3A2A);
      c.drawOval(box.inflate(2), _fill);
      _circle(c, box.center, 0, 2, 0xCCFF3A2A, oval: box.inflate(2));
    }
    if (scene.shipHealMs > 0 && scene.settings.flash) {
      _fill.color = Color((0x55 << 24) | (_heal & 0xFFFFFF));
      c.drawOval(box.inflate(2), _fill);
    }
    if (scene.shipBuffMs > 0) _circle(c, box.center, box.longestSide / 2 + 3, 1, _buff, oval: box.inflate(3));
  }

  /// 화면 번쩍(궁극기·보스 처치 등) — 화면 좌표 [box] 전체.
  void screenFlash(Canvas c, Rect box) {
    if (scene.screenFlashMs <= 0 || !scene.settings.flash) return;
    // 전체 화면 흰 번쩍 대신 금빛 가장자리 비네트(밝기 +15% 이하).
    edgeVignette(c, box, const Color(0xFFFFA41C), 0.3 * vignetteBump(1 - (scene.screenFlashMs / 200).clamp(0.0, 1.0)));
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

/// 가장자리 빛 띠(눈부심 줄이기, 사용자 '흰 번쩍임이 너무 많아 눈이 아프다'): 네 변에서 안쪽으로 [color] → 투명.
/// 둥근 그라데이션은 세로로 긴 화면에서 위아래를 통째로 덮어(탁한 올리브) 변마다 직선 띠로 그린다.
void edgeVignette(Canvas c, Rect box, Color color, double alpha) {
  // 한 프레임에 켜지지 않게 부르는 쪽이 vignetteBump(u)로 서서히 올렸다 내린다.
  if (alpha <= 0) return;
  final a = alpha.clamp(0.0, 1.0);
  final t = box.shortestSide * 0.16;
  final on = color.withValues(alpha: a);
  final off = color.withValues(alpha: 0);
  for (final (r, from, to) in [
    (Rect.fromLTWH(box.left, box.top, box.width, t), box.topCenter, box.topCenter + Offset(0, t)),
    (Rect.fromLTWH(box.left, box.bottom - t, box.width, t), box.bottomCenter, box.bottomCenter - Offset(0, t)),
    (Rect.fromLTWH(box.left, box.top, t, box.height), box.centerLeft, box.centerLeft + Offset(t, 0)),
    (Rect.fromLTWH(box.right - t, box.top, t, box.height), box.centerRight, box.centerRight - Offset(t, 0)),
  ]) {
    c.drawRect(r, Paint()..shader = Gradient.linear(from, to, [on, off]));
  }
}

/// 0 → 1 → 0 산 모양(진행률 [u] 0~1) — 비네트가 한 프레임에 켜지고 꺼지지 않게.
double vignetteBump(double u) => u <= 0 || u >= 1 ? 0 : math.sin(math.pi * u);
