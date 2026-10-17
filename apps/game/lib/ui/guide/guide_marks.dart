import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 손가락·테두리를 움직일지 — UI 시험 하네스가 끈다(되풀이 애니메이션이 pumpAndSettle을 막아서. 그림은 멈춘 첫 장면).
final guideMotionProvider = Provider<bool>((_) => true);

/// 누르는 한 번(내려가 눌림 → 원형 파동 → 올라감)의 길이 — 계속 되풀이한다(S1 2026-10-17 '가만히 있으면 안 쓴다').
const guideTapFor = Duration(milliseconds: 900);

/// 손가락 그림 크기.
const _fingerSize = 40.0;

/// 금빛.
const _gold = Color(0xFFFFD84A);

/// 누를 곳 큰 손가락: 0.9초마다 내려가 누르고(손끝에 원형 파동) 올라온다. [taps]가 바뀌면 처음부터.
/// 대상(숫자·글자)을 덮지 않게 아래에 자리가 있으면 대상 바로 아래에서 위를 가리킨다(손끝이 아랫변에 닿게) —
/// 화면 아래 끝(도크 아이콘)이면 대상 가운데 (S5 실기기 2026-10-17 — 골드 숫자를 덮음). 동작 줄이기면 가만히.
class GuideFinger extends StatefulWidget {
  const GuideFinger({required this.at, required this.taps, required this.calm, super.key});

  final Rect at;
  final int taps;
  final bool calm;

  @override
  State<GuideFinger> createState() => _GuideFingerState();
}

class _GuideFingerState extends State<GuideFinger> with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: guideTapFor);
    _sync();
  }

  @override
  void didUpdateWidget(GuideFinger old) {
    super.didUpdateWidget(old);
    if (old.taps != widget.taps) _t.value = 0;
    if (old.calm != widget.calm) _sync();
  }

  void _sync() {
    if (widget.calm) {
      _t.stop();
    } else {
      _t.repeat().ignore();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.at;
    // 아래에 둘 자리: 시스템 내비게이션 바 위까지만, 그리고 화면 아래 1/4(도크) 대상은 늘 위에서 아래로 가리킨다
    // (S1 실기기 2026-10-18 — 항해 탭을 가리킬 때 손가락이 내비게이션 바 위에 그려졌다).
    final h = MediaQuery.sizeOf(context).height;
    final below =
        at.bottom + _fingerSize + 8 <= h - MediaQuery.viewPaddingOf(context).bottom && at.center.dy < h * 0.75;
    // 손끝(아이콘 왼쪽 위 1/4 지점)이 대상에 닿는 자리.
    // 아래 자리가 없으면(도크 아이콘) 위에서 아래를 가리킨다(뒤집은 손가락) — 화면 밖으로 나가지 않게.
    final tip = below ? Offset(at.center.dx, at.bottom - 2) : Offset(at.center.dx, at.top + 2);
    return Positioned(
      left: tip.dx - _fingerSize * (below ? 0.3 : 0.7),
      top: below ? tip.dy - _fingerSize * 0.1 : tip.dy - _fingerSize * 0.9,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, child) {
            final v = _t.value;
            // 0~0.35 내려감 · 0.35~0.6 눌린 채 파동 · 0.6~1 올라감.
            final press = v < 0.35 ? v / 0.35 : (v < 0.6 ? 1.0 : 1 - (v - 0.6) / 0.4);
            final ring = v < 0.3 ? 0.0 : ((v - 0.3) / 0.55).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 손끝 원형 파동.
                if (ring > 0 && ring < 1)
                  Positioned(
                    left: _fingerSize * (below ? 0.3 : 0.7) - 6 - 14 * ring,
                    top: _fingerSize * (below ? 0.1 : 0.9) - 6 - 14 * ring,
                    child: Container(
                      key: const Key('guide.finger.ring'),
                      width: 12 + 28 * ring,
                      height: 12 + 28 * ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withValues(alpha: 1 - ring), width: 3),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, (below ? 10 : -10) * (1 - press)),
                  child: below ? child : Transform.rotate(angle: math.pi, child: child),
                ),
              ],
            );
          },
          child: const Icon(
            Icons.touch_app_rounded,
            key: Key('guide.finger'),
            size: _fingerSize,
            color: Colors.white,
            shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }
}

/// 누를 곳 굵은 금빛 맥박 테두리 + 안쪽을 살짝 밝게 — 손가락과 같은 0.9초 박자(동작 줄이기면 가만히 굵게).
class GuideGlow extends StatefulWidget {
  const GuideGlow({required this.calm, super.key});

  final bool calm;

  @override
  State<GuideGlow> createState() => _GuideGlowState();
}

class _GuideGlowState extends State<GuideGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: guideTapFor);
    if (!widget.calm) _t.repeat(reverse: true).ignore();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final p = widget.calm ? 1.0 : Curves.easeInOut.transform(_t.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04 + 0.08 * p),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold, width: 3 + 2 * p),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.5 + 0.3 * p),
                blurRadius: 10 + 10 * p,
                spreadRadius: 2 + 3 * p,
              ),
            ],
          ),
        );
      },
    ),
  );
}
