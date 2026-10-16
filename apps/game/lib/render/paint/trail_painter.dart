import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/motion.dart';

/// 등급별 폭탄 꼬리 (사용자 지시 '갖고 싶게'): 일반·희귀 없음 / 영웅 보라 불꽃 / 전설 금빛 반짝 + 별 가루 / 신화 무지개 오로라 + 빛 고리.
/// 코드 파티클(지난 위치 samples개를 다시 계산 — 저장·할당 없음). 값은 fx_map `rarityTrail`.
/// 성능: 동시 발사체가 crowd개를 넘으면 꼬리 점을 절반으로.
class TrailPainter {
  TrailPainter(this.scene);

  final BattleScene scene;
  late final JsonReader _cfg = scene.fx.raw.obj('rarityTrail');
  late final int _samples = _cfg.integer('samples');
  late final double _step = _cfg.number('step');
  late final int _crowd = _cfg.integer('crowd');
  late final List<Color> _hero = [for (final c in _cfg.strs('hero')) Color(parseArgb(c, 'rarityTrail.hero'))];
  late final List<Color> _legend = [for (final c in _cfg.strs('legend')) Color(parseArgb(c, 'rarityTrail.legend'))];
  late final List<Color> _myth = [for (final c in _cfg.strs('myth')) Color(parseArgb(c, 'rarityTrail.myth'))];
  late final Color _ring = Color(parseArgb(_cfg.str('ring'), 'rarityTrail.ring'));
  final _paint = Paint()..isAntiAlias = true;
  final _glow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

  /// 발사한 선원의 등급 (지금 프레임 함대에서).
  int rarityOf(String? crewId) {
    if (crewId == null) return 0;
    for (final s in scene.frame.fleet) {
      if (s.crewId == crewId) return s.rarity;
    }
    return 0;
  }

  /// 발사체 [p] 뒤에 꼬리를 그린다 ([bombSize] = 폭탄 크기, 도트). 그릴 게 없으면 아무것도 안 한다.
  void paint(Canvas c, Projectile p, double bombSize) {
    // 탑다운: 비행이 짧고 폭탄이 작아 꼬리가 안 보였다 — 더 길고 굵게(S1 '등급 색 꼬리').
    final size = p.flat ? bombSize * 1.5 : bombSize;
    final r = rarityOf(p.crewId);
    if (r < 2 || p.progress <= 0) return;
    final n = scene.projectiles.active.length > _crowd ? _samples ~/ 2 : _samples;
    final step = _step * _samples / n * (p.flat ? 1.8 : 1);
    final clock = scene.clockMs;
    for (var i = n; i >= 1; i--) {
      final t = p.progress - i * step;
      if (t <= 0) continue;
      final (x, gy) = positionAt(p, t);
      // 탑다운(flat): 무기 그림처럼 높이만큼 위로.
      final y = p.flat ? gy - heightAt(p, t) * 0.35 : gy;
      final k = 1 - i / (n + 1); // 0(꼬리 끝) → 1(폭탄 쪽)
      switch (r) {
        case 2:
          // 보라 불꽃: 끝으로 갈수록 작고 분홍, 살짝 일렁임.
          final wob = math.sin(clock / 60 + i) * size * 0.06;
          _glow.color = Color.lerp(_hero[1], _hero[0], k)!.withValues(alpha: 0.25 + 0.55 * k);
          c.drawCircle(Offset(x, y + wob), size * (0.12 + 0.28 * k), _glow);
        case 3:
          // 금빛 반짝 + 별 가루: 금 점 줄 + 몇 칸마다 흩어지는 작은 별(깜빡임).
          _glow.color = _legend[0].withValues(alpha: 0.3 + 0.6 * k);
          c.drawCircle(Offset(x, y), size * (0.1 + 0.24 * k), _glow);
          if (i.isOdd) {
            final seed = (p.startIndex.floor() * 13 + i * 7) % 11 - 5;
            final tw = 0.5 + 0.5 * math.sin(clock / 90 + i * 1.3);
            _star(
              c,
              x + seed * size * 0.06,
              y + (seed.isEven ? 1 : -1) * size * 0.25,
              size * 0.2 * (0.6 + tw),
              _legend[1].withValues(alpha: 0.4 + 0.6 * tw * k),
            );
          }
        default:
          // 신화 무지개 오로라: 색이 흐르는 넓은 띠.
          final hue = _myth[((i + clock / 80).floor()) % _myth.length];
          _glow.color = hue.withValues(alpha: 0.15 + 0.5 * k);
          c.drawCircle(Offset(x, y), size * (0.18 + 0.3 * k), _glow);
      }
    }
    if (r >= 4) {
      // 빛 고리: 폭탄 둘레에서 맥박.
      final pulse = 0.5 + 0.5 * math.sin(clock / 110);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.07
        ..color = _ring.withValues(alpha: 0.55 + 0.4 * pulse);
      c.drawCircle(
        Offset(p.x, p.flat ? p.y - heightAt(p, p.progress) * 0.35 : p.y),
        size * (0.55 + 0.12 * pulse),
        _paint,
      );
      _paint.style = PaintingStyle.fill;
    }
  }

  /// 네 꼭지 반짝 별.
  void _star(Canvas c, double x, double y, double s, Color color) {
    _paint.color = color;
    final path = Path()
      ..moveTo(x, y - s)
      ..lineTo(x + s * 0.25, y - s * 0.25)
      ..lineTo(x + s, y)
      ..lineTo(x + s * 0.25, y + s * 0.25)
      ..lineTo(x, y + s)
      ..lineTo(x - s * 0.25, y + s * 0.25)
      ..lineTo(x - s, y)
      ..lineTo(x - s * 0.25, y - s * 0.25)
      ..close();
    c.drawPath(path, _paint);
  }
}
