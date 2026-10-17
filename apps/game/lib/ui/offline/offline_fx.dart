import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart' show BigNum, BigNumFormat;
import 'package:pirate_dot/ui/skin/outline_text.dart';

// 복귀 창 연출 (S1 2026-10-18 '쿵푸할매 HD 결'): 밤하늘 판(별이 한 번 반짝이며 켜짐) 위에 받을 골드가 0부터 굴러 오른다.
// 반복 애니메이션 없이 창이 열릴 때 한 번만(1.2초) — 열려 있는 동안 프레임을 쓰지 않는다.

const _sky = Duration(milliseconds: 1200);

/// 밤하늘 판: 남색 그라데이션 + 별(번호로 자리 고정) — [child]를 가운데에.
class NightSkyPanel extends StatelessWidget {
  const NightSkyPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: calm ? 1 : 0, end: 1),
      duration: _sky,
      builder: (context, t, child) => CustomPaint(painter: _Stars(t), child: child),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), child: child),
    );
  }
}

class _Stars extends CustomPainter {
  _Stars(this.t);

  /// 0~1 켜짐 진행(별마다 늦춤이 달라 차례로 반짝).
  final double t;

  static const _count = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas
      ..drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2350), Color(0xFF2F3C7A)],
          ).createShader(Offset.zero & size),
      )
      ..drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF14183A),
      );
    final rnd = math.Random(7);
    for (var i = 0; i < _count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final delay = rnd.nextDouble() * 0.6;
      final k = ((t - delay) / 0.4).clamp(0.0, 1.0);
      if (k <= 0) continue;
      // 켜지는 순간 한 번 크게 반짝(1.8배) → 제 크기.
      final pop = 1 + 0.8 * math.sin(k * math.pi);
      final big = i % 5 == 0;
      final rad = (big ? 2.2 : 1.2) * pop;
      final paint = Paint()..color = Color.fromRGBO(255, 244, 200, 0.5 + 0.5 * k);
      canvas.drawCircle(Offset(x, y), rad, paint);
      if (big) {
        // 큰 별은 십자 반짝.
        final arm = rad * 2.6;
        final line = Paint()
          ..color = paint.color
          ..strokeWidth = 1.2;
        canvas
          ..drawLine(Offset(x - arm, y), Offset(x + arm, y), line)
          ..drawLine(Offset(x, y - arm), Offset(x, y + arm), line);
      }
    }
  }

  @override
  bool shouldRepaint(_Stars old) => old.t != t;
}

/// 받을 골드: 0에서 [value]까지 0.9초 굴러 오른다(끝은 정확히 [value]).
class RollUpGold extends StatelessWidget {
  const RollUpGold({required this.value, this.size = 34, super.key});

  final BigNum value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: calm ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => OutlineText(
        (t >= 1 ? value : value.times(t)).format(),
        key: const Key('offline.roll'),
        size: size,
        tone: OutlineTone.gold,
        fit: true,
      ),
    );
  }
}
