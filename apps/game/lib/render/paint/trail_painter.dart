import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/motion.dart';

/// 등급별 폭탄 꼬리 v2 (사용자 2026-10-16 '더 가늘고 길게 — 일반은 흰 가는 선, 등급 순으로 색·길이를 늘려 멋지게'):
/// 모든 등급이 꼬리를 갖는다. 폭 = 폭탄 지름 × widthRatio에서 끝으로 0까지 가늘어지고(테이퍼), 길이 = 폭탄 지름 × lengthMul[등급].
/// 일반 흰 선(옅게) · 희귀 파랑 + 끝 반짝 · 영웅 보라 이중선 + 잔상 점 · 전설 흰 코어 + 금 빛무리 + 별 가루 ·
/// 신화 무지개가 꼬리 따라 흐름 + 코어 + 빛무리 + 별 가루 + 빛 고리 맥박. 색은 rarities.json, 값은 fx_map `rarityTrail`.
/// 성능: 동시 발사체가 crowd개를 넘으면 길이는 그대로, 입자(잔상 점·별 가루)만 절반.
class TrailPainter {
  TrailPainter(this.scene);

  final BattleScene scene;
  late final JsonReader _cfg = scene.fx.raw.obj('rarityTrail');
  late final int _crowd = _cfg.integer('crowd');
  late final int _segments = _cfg.integer('segments');
  late final double _widthRatio = _cfg.number('widthRatio');
  late final List<double> _lengthMul = [for (final v in _cfg.raw['lengthMul'] as List) (v as num).toDouble()];
  late final double _commonAlpha = _cfg.number('commonAlpha');
  late final List<Color> _myth = [for (final c in _cfg.strs('myth')) Color(parseArgb(c, 'rarityTrail.myth'))];
  late final Color _ring = Color(parseArgb(_cfg.str('ring'), 'rarityTrail.ring'));
  late final List<Color> _rarity = [
    for (final r in scene.tables.rarities.rarities) Color(parseArgb(r.color, 'rarities.color')),
  ];
  static const _white = Color(0xFFFFFFFF);
  final _line = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.butt;
  final _dot = Paint()..isAntiAlias = true;

  // 꼬리 점(재사용 버퍼): 폭탄 쪽(0) → 끝(n).
  final _xs = List<double>.filled(33, 0);
  final _ys = List<double>.filled(33, 0);

  /// 발사한 선원의 등급 (지금 프레임 함대에서).
  int rarityOf(String? crewId) {
    if (crewId == null) return 0;
    for (final s in scene.frame.fleet) {
      if (s.crewId == crewId) return s.rarity;
    }
    return 0;
  }

  /// 발사체 [p] 뒤에 꼬리 ([bombSize] = 폭탄 지름, 단위).
  void paint(Canvas c, Projectile p, double bombSize) {
    if (p.progress <= 0) return;
    final r = rarityOf(p.crewId).clamp(0, _lengthMul.length - 1);
    final n = math.min(_segments, _xs.length - 1);
    final dx0 = p.toX - p.fromX;
    final dy0 = p.toY - p.fromY;
    final dist = math.max<double>(1, math.sqrt(dx0 * dx0 + dy0 * dy0));
    final span = bombSize * _lengthMul[r] / dist; // 꼬리가 차지하는 진행률
    for (var i = 0; i <= n; i++) {
      final t = math.max<double>(0, p.progress - span * i / n);
      final (x, gy) = positionAt(p, t);
      _xs[i] = x;
      _ys[i] = p.flat ? gy - heightAt(p, t) * 0.35 : gy;
    }
    final w0 = bombSize * _widthRatio;
    final clock = scene.clockMs;
    final crowded = scene.projectiles.active.length > _crowd || scene.topHits.lite;
    switch (r) {
      case 0:
        _taper(c, n, w0 * 0.7, (_) => _white.withValues(alpha: _commonAlpha));
      case 1:
        final col = _rarity[1];
        _taper(c, n, w0, (k) => col.withValues(alpha: 0.85 * (1 - k * 0.6)));
        _sparkle(c, _xs[n], _ys[n], w0 * 1.2, _white.withValues(alpha: 0.5 + 0.5 * math.sin(clock / 80)));
      case 2:
        final col = _rarity[2];
        // 가는 이중선: 진행 방향에 수직으로 ±w0*0.7
        final (nx, ny) = _normal(n);
        for (final side in const [-1.0, 1.0]) {
          _taper(
            c,
            n,
            w0 * 0.6,
            (k) => col.withValues(alpha: 0.9 * (1 - k * 0.5)),
            ox: nx * w0 * 0.7 * side,
            oy: ny * w0 * 0.7 * side,
          );
        }
        _taper(c, n, w0 * 0.35, (k) => _white.withValues(alpha: 0.7 * (1 - k)));
        for (var i = 2; i <= n; i += crowded ? 4 : 2) {
          _dot.color = col.withValues(alpha: 0.5 * (1 - i / n));
          c.drawCircle(Offset(_xs[i], _ys[i]), w0 * 0.55, _dot);
        }
      case 3:
        final gold = _rarity[3];
        _taper(c, n, w0 * 2.2, (k) => gold.withValues(alpha: 0.28 * (1 - k)));
        _taper(c, n, w0, (k) => gold.withValues(alpha: 0.95 * (1 - k * 0.4)));
        _taper(c, n, w0 * 0.45, (k) => _white.withValues(alpha: 1 - k));
        _dust(c, n, bombSize, gold, clock, crowded: crowded);
      default:
        Color flow(double k) => _myth[((k * _myth.length + clock / 90) % _myth.length).floor()];
        _taper(c, n, w0 * 2.4, (k) => flow(k).withValues(alpha: 0.3 * (1 - k)));
        _taper(c, n, w0 * 1.1, (k) => flow(k).withValues(alpha: 0.95 * (1 - k * 0.3)));
        _taper(c, n, w0 * 0.45, (k) => _white.withValues(alpha: 1 - k));
        _dust(c, n, bombSize, flow(0.5), clock, crowded: crowded);
        final pulse = 0.5 + 0.5 * math.sin(clock / 110);
        _line
          ..style = PaintingStyle.stroke
          ..strokeWidth = bombSize * 0.07
          ..color = _ring.withValues(alpha: 0.55 + 0.4 * pulse);
        c.drawCircle(Offset(_xs[0], _ys[0]), bombSize * (0.55 + 0.12 * pulse), _line);
        _line.style = PaintingStyle.fill;
    }
  }

  /// 진행 방향 단위 수직 벡터.
  (double, double) _normal(int n) {
    final dx = _xs[0] - _xs[n ~/ 2];
    final dy = _ys[0] - _ys[n ~/ 2];
    final len = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
    return (-dy / len, dx / len);
  }

  /// 폭탄 쪽 폭 [w0]에서 끝 0까지 가늘어지는 선. [color]는 0(폭탄 쪽)~1(끝) 위치별 색.
  void _taper(Canvas c, int n, double w0, Color Function(double k) color, {double ox = 0, double oy = 0}) {
    _line.style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final k = i / n;
      _line
        ..strokeWidth = math.max(0.3, w0 * (1 - k))
        ..color = color(k);
      c.drawLine(Offset(_xs[i] + ox, _ys[i] + oy), Offset(_xs[i + 1] + ox, _ys[i + 1] + oy), _line);
    }
    _line.style = PaintingStyle.fill;
  }

  /// 별 가루: 꼬리 둘레에 흩날리며 깜빡이는 작은 네 꼭지 별.
  void _dust(Canvas c, int n, double size, Color color, double clock, {required bool crowded}) {
    for (var i = 1; i <= n; i += crowded ? 4 : 2) {
      final seed = (i * 37 + 11) % 13 - 6;
      final tw = 0.5 + 0.5 * math.sin(clock / 90 + i * 1.3);
      _sparkle(
        c,
        _xs[i] + seed * size * 0.06,
        _ys[i] + (seed.isEven ? 1 : -1) * size * 0.3,
        size * 0.18 * (0.6 + tw),
        color.withValues(alpha: (0.4 + 0.6 * tw) * (1 - i / n)),
      );
    }
  }

  final _star = Path();

  /// 네 꼭지 반짝 별.
  void _sparkle(Canvas c, double x, double y, double s, Color color) {
    _dot.color = color;
    _star
      ..reset()
      ..moveTo(x, y - s)
      ..lineTo(x + s * 0.25, y - s * 0.25)
      ..lineTo(x + s, y)
      ..lineTo(x + s * 0.25, y + s * 0.25)
      ..lineTo(x, y + s)
      ..lineTo(x - s * 0.25, y + s * 0.25)
      ..lineTo(x - s, y)
      ..lineTo(x - s * 0.25, y - s * 0.25)
      ..close();
    c.drawPath(_star, _dot);
  }
}
