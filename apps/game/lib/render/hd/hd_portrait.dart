import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD 카툰 초상(UI용 — 도감 칸·보스 이름표·현상금·보스 도전 버튼): 전장과 같은 종 코드 벡터를 [size] 칸에 그린다.
/// 굽지 않고 바로 그린다(초상은 한 화면 수십 장·정지 그림이라 시트보다 가볍다 — RepaintBoundary로 한 번만).
/// [animate]면 0.8초 고리로 움직인다(도감 상세 등 크게 보일 때만 — 목록 칸은 정지). 기기 '애니메이션 줄이기'면
/// 스스로 멈추고, 절전·발열(보통 이상)일 때는 부르는 쪽이 animate: false로 넘긴다(S4 — UI 상태는 render가 모른다).
/// HD 종이 아니면 [fallback](지금 도트 그림)을 그린다 — 종이 하나씩 HD로 바뀌어도 UI가 그대로 동작한다.
class HdPortrait extends StatefulWidget {
  const HdPortrait({
    required this.kind,
    this.boss = false,
    this.size = 48,
    this.animate = false,
    this.shadow = false,
    this.fallback,
    this.moods = false,
    this.silhouette = false,
    super.key,
  });

  /// 표정 3종 순환(도감 보스 상세 — S1): animate일 때 평소 → 공격 예고(붉은 눈) → 쓰러짐(소용돌이 눈·기우뚱·별) 0.8초씩.
  final bool moods;

  /// 못 만난 보스: 남색 실루엣(모양만).
  final bool silhouette;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HdPortrait old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.moods != widget.moods) {
      _loop?.dispose();
      _loop = null;
      _sync();
    }
  }

  bool get _moving => widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_moving && _loop == null) {
      _loop = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.moods ? 2400 : 800),
      );
      unawaited(_loop!.repeat());
    } else if (!_moving && _loop != null) {
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
          painter: _PortraitPainter(
            sp,
            _loop,
            shadow: widget.shadow,
            moods: widget.moods,
            silhouette: widget.silhouette,
            selfMood: hdMoodSpecies.contains(widget.kind),
          ),
        ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(
    this.sp,
    this.loop, {
    required this.shadow,
    this.moods = false,
    this.silhouette = false,
    this.selfMood = true,
  }) : super(repaint: loop);

  final HdSpecies sp;
  final bool shadow;
  final bool moods;
  final bool silhouette;
  final bool selfMood;
  final AnimationController? loop;
  static final _shade = Paint()..colorFilter = const ColorFilter.mode(Color(0xFF1B2A4A), BlendMode.srcIn);
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / (2 * sp.extent);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2);
    if (silhouette) canvas.saveLayer(Rect.fromCircle(center: Offset.zero, radius: size.longestSide), _shade);
    final v = loop?.value ?? 0;
    final phase = moods ? (v * 3).floor().clamp(0, 2) : 0;
    final t = (moods ? (v * 3) % 1 : v) * HdKit.loopMs;
    _k
      ..mood = const [HdMood.idle, HdMood.windup, HdMood.down][phase]
      ..begin(r);
    if (shadow) _k.shadow(canvas, r, sp.ground);
    // 쓰러짐: 표정을 직접 안 그리는 종은 굽기와 같이 기우뚱 + 머리 위 별(HdSheets.bake와 같은 규칙)
    final generic = !selfMood && _k.mood == HdMood.down;
    if (generic) _k.downTilt(canvas, r * 0.9, t);
    sp.draw(_k, canvas, r, t);
    if (generic) {
      canvas.restore();
      _k.dizzyStars(canvas, Offset(0, -r * sp.extent * 0.8), r, t);
    }
    if (silhouette) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.sp != sp || old.shadow != shadow || old.moods != moods || old.silhouette != silhouette;
}
