import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';

// 소환 연출 효과 (사용자 지시 2026-10-15: 카드를 열 때 기대감). 모두 끝이 있는 애니메이션이다(무한 반복 없음 — 배터리·테스트).

/// 등급 순번 (rarities.json 순서: 0 일반 … 4 신화).
abstract final class Tier {
  static const rare = 1;
  static const hero = 2;
  static const legend = 3;
  static const mythic = 4;
}

/// 뒷면 기대감: 희귀 이상은 테두리 빛, 영웅 이상은 떨림 + 등급 색 빛 기둥. [t]는 0→1 (한 번).
class CardHint extends StatelessWidget {
  const CardHint({required this.tier, required this.color, required this.t, required this.child, super.key});

  final int tier;
  final Color color;
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tier < Tier.rare) return child;
    // 떨림: 영웅 이상, 진폭이 커졌다가 잦아든다.
    final shake = tier >= Tier.hero ? math.sin(t * math.pi * 14) * 3 * math.sin(t * math.pi) * (tier - 1) / 2 : 0.0;
    final glow = [
      for (final (c, blur) in pbGlow[_glowKey(tier)] ?? const <(Color, double)>[])
        BoxShadow(color: c, blurRadius: blur * (1.5 + 2 * t), spreadRadius: 1 + 3 * t),
    ];
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 빛 기둥: 카드 뒤로 위아래로 솟는 등급 색 띠.
        if (tier >= Tier.hero)
          Positioned(
            top: -80 * t,
            bottom: -80 * t,
            left: 10,
            right: 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0),
                      color.withValues(alpha: 0.55 * t),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(shake, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: glow),
            child: child,
          ),
        ),
      ],
    );
  }

  static String _glowKey(int tier) => switch (tier) {
    Tier.rare => 'rare',
    Tier.hero => 'hero',
    Tier.legend => 'legend',
    _ => 'mythic',
  };
}

/// 전설 금빛 파티클 / 신화 무지개: 화면 위로 흩어지는 점(상한 [_maxParticles]). [t] 0→1 한 번.
class SparkBurst extends StatelessWidget {
  const SparkBurst({required this.t, required this.rainbow, super.key});

  final double t;
  final bool rainbow;

  static const _maxParticles = 28;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _SparkPainter(t, rainbow: rainbow),
      size: Size.infinite,
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t, {required this.rainbow});

  final double t;
  final bool rainbow;

  static const _rainbow = [
    Color(0xFFFF6FD8),
    Color(0xFF7AF0FF),
    Color(0xFFFFE27A),
    Color(0xFF8CFFB0),
    Color(0xFFB98CFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rng = math.Random(7);
    final c = size.center(Offset.zero);
    final paint = Paint();
    for (var i = 0; i < SparkBurst._maxParticles; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 0.25 + rng.nextDouble() * 0.45;
      final d = speed * size.shortestSide * Curves.easeOut.transform(t);
      final p = c + Offset(math.cos(angle) * d, math.sin(angle) * d - 40 * t);
      paint.color = (rainbow ? _rainbow[i % _rainbow.length] : const Color(0xFFFFD447)).withValues(alpha: 1 - t);
      final r = 2.5 + rng.nextDouble() * 3.5;
      canvas.drawCircle(p, r * (1 - 0.4 * t), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.rainbow != rainbow;
}

/// 신화 오로라: 화면 위쪽에 흐르는 무지개 띠. [t] 0→1 한 번.
class AuroraSweep extends StatelessWidget {
  const AuroraSweep({required this.t, super.key});

  final double t;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: math.sin(t * math.pi).clamp(0, 1).toDouble() * 0.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * t, -1),
            end: Alignment(1 + 2 * t, 0.2),
            colors: const [
              Color(0x00FF6FD8),
              Color(0xFFFF6FD8),
              Color(0xFF7AF0FF),
              Color(0xFFFFE27A),
              Color(0x007AF0FF),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 3D 뒤집기: [t] 0→0.5 뒷면이 옆으로 눕고, 0.5→1 앞면이 일어난다.
class FlipCard extends StatelessWidget {
  const FlipCard({required this.t, required this.back, required this.front, super.key});

  final double t;
  final Widget back;
  final Widget front;

  @override
  Widget build(BuildContext context) {
    final showFront = t >= 0.5;
    final angle = (showFront ? 1 - t : t) * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      child: showFront ? front : back,
    );
  }
}

/// ‘NEW’ 도장: 크게 떨어져 쾅 찍힌다. [t] 0→1.
class NewStamp extends StatelessWidget {
  const NewStamp({required this.t, required this.label, super.key});

  final double t;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final s = 2.2 - 1.2 * Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t.clamp(0, 1).toDouble(),
      child: Transform.rotate(
        angle: -0.22,
        child: Transform.scale(
          scale: s,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF4A5E), width: 3),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.85),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Jua',
                fontSize: 14,
                color: Color(0xFFFF4A5E),
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
