import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// 가이드 층의 표시들: 어둡게(구멍만 밝게) · 구멍 밖 누름 막기 · 톡톡 손가락.

/// 전체를 [alpha]만큼 어둡게, [holes]만 밝게(둥근 구멍).
class GuideDimPainter extends CustomPainter {
  GuideDimPainter({required this.holes, required this.alpha});

  final List<Rect> holes;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final h in holes) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(RRect.fromRectAndRadius(h.inflate(6), const Radius.circular(12))),
      );
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(GuideDimPainter old) => old.alpha != alpha || old.holes != holes;
}

/// 구멍 밖 누름을 삼키고 [onBlocked]를 부른다. 구멍 안은 아래 위젯이 받는다.
class GuideHoleBlocker extends LeafRenderObjectWidget {
  const GuideHoleBlocker({required this.holes, required this.onBlocked, super.key});

  final List<Rect> holes;
  final VoidCallback onBlocked;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderGuideHoleBlocker(holes, onBlocked);

  @override
  void updateRenderObject(BuildContext context, RenderGuideHoleBlocker renderObject) => renderObject
    ..holes = holes
    ..onBlocked = onBlocked;
}

class RenderGuideHoleBlocker extends RenderBox {
  RenderGuideHoleBlocker(this.holes, this.onBlocked);

  List<Rect> holes;
  VoidCallback onBlocked;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => !holes.any((h) => h.inflate(6).contains(position));

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) onBlocked();
  }
}

/// 가리킨 곳 오른쪽 아래 모서리에 큰 손가락 — 3번 톡톡 누르고 멈춘다([taps]가 바뀌면 다시). 동작 줄이기면 가만히.
class GuideFinger extends StatelessWidget {
  const GuideFinger({required this.at, required this.taps, required this.calm, super.key});

  final Rect at;
  final int taps;
  final bool calm;

  @override
  Widget build(BuildContext context) => Positioned(
    // 글자(탭 이름 등)를 덮지 않게 오른쪽 아래 모서리.
    left: at.right - 24,
    top: at.bottom - 28,
    child: IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(taps),
        tween: Tween(begin: 0, end: calm ? 0 : 3),
        duration: const Duration(milliseconds: 2400),
        builder: (_, v, child) {
          // 한 번 톡 = 0.8초: 아래로 눌렀다 올라옴.
          final t = v - v.floor();
          final press = v >= 3 ? 0.0 : (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Transform.translate(offset: Offset(0, -8 * press), child: child);
        },
        child: const Icon(
          Icons.touch_app_rounded,
          key: Key('guide.finger'),
          size: 40,
          color: Colors.white,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
      ),
    ),
  );
}
