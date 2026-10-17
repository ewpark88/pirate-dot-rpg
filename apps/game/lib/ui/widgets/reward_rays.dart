import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 보상 연출 등급 → 빛·칸 색 (디자인 개편 ③, 쿵푸할매 상자 연출): 초록 · 파랑 · 보라 · 금 · 무지개.
enum RewardTier {
  green(Color(0xFF5BE37A)),
  blue(Color(0xFF4FA8FF)),
  purple(Color(0xFFB06BFF)),
  gold(Color(0xFFFFD34A)),
  rainbow(Color(0xFFFF6BD0));

  const RewardTier(this.color);

  /// 빛·칸 색(무지개는 빛줄기만 무지개, 칸·가운데 빛은 이 색).
  final Color color;
}

/// 보상 터짐 뒤 빛(RewardBurst): 회전 빛기둥(등급색 · 옅은 흰색 번갈아) + 둥근 빛 + 깜빡이는 반짝이 별. [t] 0~1 펼침, [spin] 라디안.
class RewardRaysPainter extends CustomPainter {
  RewardRaysPainter({
    required this.center,
    required this.t,
    required this.spin,
    required this.tier,
    required this.lite,
  });

  final Offset center;
  final double t;
  final double spin;
  final RewardTier tier;
  final bool lite;

  Color _ray(int i, int n) =>
      tier == RewardTier.rainbow ? HSVColor.fromAHSV(1, 360 * i / n, 0.75, 1).toColor() : tier.color;

  @override
  void paint(Canvas canvas, Size size) {
    // 빛은 빠르게 펼쳐지고(0~0.25) 그 뒤 유지.
    final grow = Curves.easeOutCubic.transform((t / 0.25).clamp(0.0, 1.0));
    if (grow <= 0) return;
    final radius = math.min(size.width, size.height) * 0.62 * grow;
    final n = lite ? 8 : 14;
    final half = math.pi / n * 0.45;
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < n; i++) {
      final a = spin + i * 2 * math.pi / n;
      final p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - half) * radius, center.dy + math.sin(a - half) * radius)
        ..lineTo(center.dx + math.cos(a + half) * radius, center.dy + math.sin(a + half) * radius)
        ..close();
      // 색 빛줄기와 옅은 흰 빛줄기를 번갈아 — 아이콘이 빛에 묻히지 않게 밖으로 갈수록 사라진다.
      final col = i.isEven ? _ray(i, n) : Colors.white;
      paint.shader = RadialGradient(
        colors: [
          col.withValues(alpha: i.isEven ? 0.55 : 0.3),
          col.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawPath(p, paint);
    }
    // 가운데 둥근 빛.
    final glow = _ray(0, n);
    canvas.drawCircle(
      center,
      radius * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.95), glow.withValues(alpha: 0.6), glow.withValues(alpha: 0)],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.32)),
    );
    // 반짝이 별(결정론 자리, 깜빡임).
    final stars = lite ? 6 : 16;
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < stars; i++) {
      final h = (i * 2654435761) & 0xFFFFFF;
      final a = (h % 628) / 100;
      final d = radius * (0.25 + (h >> 10) % 60 / 100);
      final tw = math.max<double>(0, math.sin(t * 9 + i * 1.7));
      final s = (3 + (h >> 4) % 5) * tw * grow;
      if (s < 0.5) continue;
      final at = center + Offset(math.cos(a) * d, math.sin(a) * d * 0.8);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - s * 2)
          ..quadraticBezierTo(at.dx, at.dy, at.dx + s * 2, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + s * 2)
          ..quadraticBezierTo(at.dx, at.dy, at.dx - s * 2, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - s * 2),
        star,
      );
    }
  }

  @override
  bool shouldRepaint(RewardRaysPainter old) => old.t != t || old.spin != spin || old.tier != tier;
}
