import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 보상 반짝임 (스킨 r2 ⑤): 받은 숫자 둘레에 별 6개가 0.8초 반짝이고 사라진다(한 번 — 끝이 있음).
/// 상자 팝업·오프라인 보상처럼 '받았다'를 보여 줄 때 숫자를 감싼다. 동작 줄이기 설정이면 그대로 둔다.
class RewardSparkle extends StatefulWidget {
  const RewardSparkle({required this.child, this.seed = 3, super.key});

  final Widget child;

  /// 별 자리 (같은 화면에 여러 개면 다르게).
  final int seed;

  @override
  State<RewardSparkle> createState() => _RewardSparkleState();
}

class _RewardSparkleState extends State<RewardSparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && _t.value == 0) _t.forward().ignore();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => CustomPaint(
      foregroundPainter: _t.isAnimating ? _StarsPainter(_t.value, widget.seed) : null,
      child: child,
    ),
    child: widget.child,
  );
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.t, this.seed);

  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    for (var i = 0; i < 6; i++) {
      // 별마다 조금씩 늦게 반짝: 커졌다 작아진다.
      final start = i * 0.08;
      final local = ((t - start) / 0.5).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final pop = math.sin(local * math.pi);
      final c = Offset(
        -6 + rng.nextDouble() * (size.width + 12),
        -6 + rng.nextDouble() * (size.height + 12),
      );
      final r = (4 + rng.nextDouble() * 4) * pop;
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final rr = k.isEven ? r : r * 0.35;
        final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas
        ..drawPath(path, Paint()..color = (i.isEven ? const Color(0xFFFFC93C) : const Color(0xFFFFF3B0)))
        ..drawPath(
          path,
          Paint()
            ..color = const Color(0x80D98A00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}
