import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 보상 하나: HD 아이콘 경로(UiSprites) + 수량 글자(이미 줄여 쓴 '1.2K' 등).
typedef RewardItem = ({String icon, String label});

/// 보상 연출 등급 → 빛 색 (디자인 개편 ③, 쿵푸할매 상자 연출): 0 초록 · 1 파랑 · 2 보라 · 3 금 · 4 무지개.
enum RewardTier { green, blue, purple, gold, rainbow }

/// 보상 터짐(디자인 개편 ③ — 참고 이미지 상자 연출): 가운데 뒤로 회전 빛기둥(방사선) + 둥근 빛 + 반짝이 별,
/// 아이템 아이콘이 위로 튀어 부채꼴로 쏟아졌다가 아래 칸 줄로 정렬된다. 보물상자·보스 보상·도감 보상·소환 결과 창이
/// 기존 연출(TopBossLoot·ChestOpened) 위에 덮개로 얹는다 — 누름은 통과(IgnorePointer).
/// [lite](절전·발열)면 빛줄기 수·반짝이를 줄이고 회전을 멈춘다. [progress]를 주면 그 순간에 멈춘다(골든 시험).
class RewardBurst extends StatefulWidget {
  const RewardBurst({required this.items, this.tier = RewardTier.gold, this.lite = false, this.progress, super.key});

  final List<RewardItem> items;
  final RewardTier tier;
  final bool lite;
  final double? progress;

  /// 터짐부터 정렬까지(그 뒤 빛은 천천히 계속 돈다).
  static const duration = Duration(milliseconds: 1800);

  @override
  State<RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<RewardBurst> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.progress != null) return;
    _c = AnimationController(vsync: this, duration: RewardBurst.duration);
    unawaited(_c!.forward());
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _c == null
        ? _frame(widget.progress!, 0)
        : AnimatedBuilder(
            animation: _c!,
            builder: (context, _) => _frame(_c!.value, (_c!.lastElapsedDuration?.inMilliseconds ?? 0) / 1000),
          ),
  );

  Widget _frame(double t, double sec) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final center = Offset(size.width / 2, size.height * 0.42);
      final icon = math.min<double>(72, size.width / (widget.items.length.clamp(3, 6) + 1.6));
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RaysPainter(
                center: center,
                t: t,
                spin: widget.lite ? 0 : (widget.progress ?? sec) * 0.6,
                tier: widget.tier,
                lite: widget.lite,
              ),
            ),
          ),
          for (final (i, item) in widget.items.indexed) _item(i, item, t, center, size, icon),
        ],
      );
    },
  );

  /// 아이템 i: 0~0.45 가운데에서 부채꼴로 위로 튀었다 떨어짐 → 0.45~0.8 아래 줄 칸으로 → 이후 제자리(살짝 출렁).
  Widget _item(int i, RewardItem item, double t, Offset center, Size size, double icon) {
    final n = widget.items.length;
    final perRow = math.min(n, 5);
    final row = i ~/ perRow;
    final col = i % perRow;
    final inRow = math.min(perRow, n - row * perRow);
    final gap = icon * 1.25;
    final slot = Offset(
      size.width / 2 + (col - (inRow - 1) / 2) * gap,
      center.dy + icon * 1.6 + row * (icon * 1.45),
    );
    // 부채꼴 정점: 가운데 위로 퍼짐(순서대로 −60°~+60°).
    final fan = n == 1 ? 0.0 : (i / (n - 1) - 0.5) * 2 * math.pi / 3;
    final peak = center + Offset(math.sin(fan) * icon * 2.2, -icon * 2.4 - math.cos(fan) * icon * 0.6);
    final delay = i * 0.04;
    final u = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    Offset at;
    double scale;
    if (u < 0.45) {
      final k = u / 0.45;
      // 위로 솟았다가(ease-out) 정점.
      at = Offset.lerp(center, peak, Curves.easeOutCubic.transform(k))!;
      scale = 0.3 + 0.9 * Curves.easeOutBack.transform(k);
    } else if (u < 0.8) {
      final k = Curves.easeInOutCubic.transform((u - 0.45) / 0.35);
      at = Offset.lerp(peak, slot, k)!;
      scale = 1.2 - 0.2 * k;
    } else {
      at = slot;
      scale = 1 + 0.06 * math.sin((u - 0.8) / 0.2 * math.pi);
    }
    final visible = t > delay;
    return Positioned(
      left: at.dx - icon / 2,
      top: at.dy - icon / 2,
      width: icon,
      height: icon * 1.5,
      child: Opacity(
        opacity: visible ? 1 : 0,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Image.asset(item.icon, width: icon, height: icon, key: Key('reward.item.$i')),
              _OutlinedLabel(item.label, size: math.max(12, icon * 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 흰 글자 + 검은 테두리(쿵푸할매 톤).
class _OutlinedLabel extends StatelessWidget {
  const _OutlinedLabel(this.text, {required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = Skin.text(size, color: Colors.white, weight: FontWeight.w800);
    return FittedBox(
      child: Stack(
        children: [
          Text(
            text,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.28
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF1B1626),
            ),
          ),
          Text(text, style: base),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.center, required this.t, required this.spin, required this.tier, required this.lite});

  final Offset center;
  final double t;
  final double spin;
  final RewardTier tier;
  final bool lite;

  static const Map<RewardTier, Color> _tierColors = {
    RewardTier.green: Color(0xFF5BE37A),
    RewardTier.blue: Color(0xFF4FA8FF),
    RewardTier.purple: Color(0xFFB06BFF),
    RewardTier.gold: Color(0xFFFFD34A),
  };

  Color _ray(int i, int n) =>
      tier == RewardTier.rainbow ? HSVColor.fromAHSV(1, 360 * i / n, 0.75, 1).toColor() : _tierColors[tier]!;

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
  bool shouldRepaint(_RaysPainter old) => old.t != t || old.spin != spin || old.tier != tier;
}
