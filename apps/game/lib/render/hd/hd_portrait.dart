import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD 카툰 초상(UI용 — 도감 칸·보스 이름표·현상금·보스 도전 버튼): 전장과 같은 종 코드 벡터를 [size] 칸에 그린다.
/// 굽지 않고 바로 그린다(초상은 한 화면 수십 장·정지 그림이라 시트보다 가볍다 — RepaintBoundary로 한 번만).
/// [animate]면 0.8초 고리로 움직인다(도감 상세 등 크게 보일 때만 — 목록 칸은 정지).
/// HD 종이 아니면 [fallback](지금 도트 그림)을 그린다 — 종이 하나씩 HD로 바뀌어도 UI가 그대로 동작한다.
class HdPortrait extends StatefulWidget {
  const HdPortrait({
    required this.kind,
    this.boss = false,
    this.size = 48,
    this.animate = false,
    this.shadow = false,
    this.fallback,
    super.key,
  });

  /// 엔진 적 kind(regions 적 id) 또는 보스 id(fx_map bossLook 키).
  final String kind;
  final bool boss;
  final double size;
  final bool animate;

  /// 발밑 그림자(전장처럼) — 초상은 기본 없음.
  final bool shadow;

  /// HD 종이 아닐 때 그릴 것(지금 도트). 없으면 빈 칸.
  final Widget? fallback;

  /// 이 kind가 HD로 그려지나.
  static bool has(String kind, {bool boss = false}) => (boss ? hdBosses : hdEnemies).containsKey(kind);

  @override
  State<HdPortrait> createState() => _HdPortraitState();
}

class _HdPortraitState extends State<HdPortrait> with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HdPortrait old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate && _loop == null) {
      _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      unawaited(_loop!.repeat());
    } else if (!widget.animate && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = (widget.boss ? hdBosses : hdEnemies)[widget.kind];
    if (sp == null) return SizedBox.square(dimension: widget.size, child: widget.fallback);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          key: Key('hd.portrait.${widget.kind}'),
          painter: _PortraitPainter(sp, _loop, shadow: widget.shadow),
        ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.sp, this.loop, {required this.shadow}) : super(repaint: loop);

  final HdSpecies sp;
  final bool shadow;
  final AnimationController? loop;
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / (2 * sp.extent);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2);
    _k.begin(r);
    if (shadow) _k.shadow(canvas, r, sp.ground);
    sp.draw(_k, canvas, r, (loop?.value ?? 0) * HdKit.loopMs);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.sp != sp || old.shadow != shadow;
}
