import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';

// 선원 레벨업 반짝이 (S1 2026-10-17, 개편 — 엔진 이벤트 없음이라 UI가 레벨이 오른 것을 보고 띄운다):
// 카드 위 'LEVEL UP!'(금 외곽선 글자)가 솟고 별 6개가 칸 위로 튀며, 카드는 살짝 튕긴다(0.3초).
// 일괄 합치기로 여러 장이 한 프레임에 오르면 0.08초 간격으로 차례로.

/// 전체 연출 길이 / 카드 튕김 길이 / 일괄일 때 카드 사이 간격.
const levelUpFxFor = Duration(milliseconds: 900);
const double _bounceFor = 0.3 / 0.9;
const levelUpStagger = Duration(milliseconds: 80);

/// 별 수.
const _stars = 6;

class LevelUpFx extends StatefulWidget {
  const LevelUpFx({required this.level, required this.child, super.key});

  /// 지금 레벨 (null = 미보유). 오르면 연출.
  final int? level;
  final Widget child;

  @override
  State<LevelUpFx> createState() => _LevelUpFxState();
}

class _LevelUpFxState extends State<LevelUpFx> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: levelUpFxFor);

  // 같은 프레임에 시작한 연출 수 (일괄 합치기 차례).
  static Duration? _frame;
  static int _inFrame = 0;

  @override
  void didUpdateWidget(LevelUpFx old) {
    super.didUpdateWidget(old);
    final was = old.level;
    final now = widget.level;
    if (was == null || now == null || now <= was) return;
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    _inFrame = stamp == _frame ? _inFrame + 1 : 0;
    _frame = stamp;
    final wait = levelUpStagger * _inFrame;
    Future<void>.delayed(wait, () {
      if (mounted) _t.forward(from: 0).ignore();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        if (!_t.isAnimating) return child!;
        // 카드 튕김: 0~0.3초 동안 1 → 1.08 → 1.
        final b = (v / _bounceFor).clamp(0.0, 1.0);
        final scale = calm ? 1.0 : 1 + 0.08 * math.sin(b * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(scale: scale, child: child),
            if (!calm)
              for (var i = 0; i < _stars; i++) _star(i, v),
            // 'LEVEL UP!': 위로 솟으며 끝에 흐려진다.
            Positioned(
              left: -12,
              right: -12,
              top: -8 - 26 * Curves.easeOut.transform(v),
              child: IgnorePointer(
                child: Opacity(
                  opacity: v < 0.75 ? 1 : (1 - (v - 0.75) / 0.25).clamp(0.0, 1.0),
                  child: Center(
                    child: OutlineText(
                      AppLocalizations.of(context).uiLevelUpFx,
                      key: const Key('crew.levelUpFx'),
                      size: 18,
                      tone: OutlineTone.gold,
                      fit: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 별 하나: 카드 아래쪽에서 부채꼴로 솟아 흐려진다.
  Widget _star(int i, double v) {
    final angle = -math.pi / 2 + (i - (_stars - 1) / 2) * 0.42;
    final d = 46 * Curves.easeOut.transform(v);
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, 0.4),
          child: Transform.translate(
            offset: Offset(math.cos(angle) * d, math.sin(angle) * d),
            child: Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFD84A)),
            ),
          ),
        ),
      ),
    );
  }
}
