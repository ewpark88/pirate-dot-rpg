import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 보상(금색) 버튼 빛 줄기 주기·길이 (스킨 r2 결정 ①: 5초).
const _shineEvery = Duration(seconds: 5);
const _shineFor = Duration(milliseconds: 700);

/// 버튼 색 종류.
enum SkinTone {
  /// 누르면 이득인 주 버튼 — 초록(k1).
  primary,

  /// 받기·광고 보상·일괄 합치기 — 금색.
  gold,

  /// 닫기·취소 같은 보조 — 흰색.
  plain,
}

/// 통통한 버튼 (스킨 r1): 위가 밝은 그라데이션 + 아래 진한 테두리 [Skin.buttonEdge] + 흰 안쪽 테두리.
/// 누르면 테두리만큼 내려앉으며 95%로 줄고, 놓으면 통 튀어 돌아온다(easeOutBack). 누르는 영역은 최소 48dp.
/// [onPressed]가 null이면 회색.
class SkinButton extends StatefulWidget {
  const SkinButton({
    required this.onPressed,
    required this.child,
    this.tone = SkinTone.primary,
    this.height = 48,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final SkinTone tone;
  final double height;
  final String? semanticLabel;

  @override
  State<SkinButton> createState() => _SkinButtonState();
}

class _SkinButtonState extends State<SkinButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  );

  /// 빛 줄기 (금색 버튼만, 한 번 지나가는 애니메이션을 5초마다).
  late final AnimationController _shine = AnimationController(vsync: this, duration: _shineFor);
  Timer? _shineTimer;

  ProviderContainer? get _container {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } on Object {
      return null; // 앱 밖(단독 위젯 테스트)에서는 소리·설정 없음.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shineTimer?.cancel();
    _shineTimer = null;
    if (widget.tone != SkinTone.gold || widget.onPressed == null || MediaQuery.disableAnimationsOf(context)) return;
    final settings = _container?.read(gameStateProvider).settings;
    // 절전·번쩍임 끄기면 빛 줄기 없음.
    if (settings != null && (settings.powerSave || !settings.flash)) return;
    _shineTimer = Timer.periodic(_shineEvery, (_) {
      if (mounted) _shine.forward(from: 0).ignore();
    });
  }

  /// 누를 때 짧은 '톡' (스킨 r2 결정 ②: 주 버튼(파랑·금색)만, 기존 pop.ogg 높은 음 — 설정 효과음을 따른다).
  void _tock() {
    if (widget.tone == SkinTone.plain) return;
    _container?.read(audioPortProvider)?.playSfx('pop', pitch: 1.6);
  }

  @override
  void dispose() {
    _shineTimer?.cancel();
    _shine.dispose();
    _press.dispose();
    super.dispose();
  }

  (Color, Color, Color, Color) get _colors => switch (widget.tone) {
    _ when widget.onPressed == null => (Skin.disabled, Skin.disabled, const Color(0xFFAEB9CB), Colors.white),
    SkinTone.primary => (Skin.primaryTop, Skin.primaryBottom, Skin.primaryEdge, Colors.white),
    SkinTone.gold => (Skin.goldTop, Skin.goldBottom, Skin.goldEdge, Skin.goldInk),
    SkinTone.plain => (Skin.plainTop, Skin.plainBottom, Skin.plainEdge, Skin.ink),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (top, bottom, edge, ink) = _colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (_) {
                _tock();
                _press.forward().ignore();
              }
            : null,
        onTapCancel: enabled ? _press.reverse : null,
        onTapUp: enabled ? (_) => _press.reverse() : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 48, minHeight: widget.height < 48 ? 48 : widget.height),
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, child) {
              // easeOutBack은 놓을 때 0 밑으로 살짝 넘친다 — 크기만 통 튀고, 내려앉는 거리는 0~1로 자른다.
              final bounce = _t.value;
              final p = bounce.clamp(0.0, 1.0);
              return Transform.scale(
                scale: 1 - 0.05 * bounce,
                child: Padding(
                  // 눌리면 아래 테두리 자리로 내려앉는다(전체 높이는 그대로).
                  padding: EdgeInsets.only(top: Skin.buttonEdge * p),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: edge,
                      borderRadius: BorderRadius.circular(Skin.radiusButton),
                      // k1: 굵은 검정 외곽선.
                      border: Border.all(color: Skin.outline, width: 2),
                      boxShadow: p > 0.5 ? null : Skin.shadowSmall,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: Skin.buttonEdge * (1 - p)),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: _Gloss(
              shine: widget.tone == SkinTone.gold ? _shine : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, bottom],
                  ),
                  borderRadius: BorderRadius.circular(Skin.radiusButton),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: DefaultTextStyle.merge(
                      // 초록·회색 버튼은 흰 외곽선 글자(k1), 금색·보조는 진한 글자.
                      // k2: 굵은 글자 17sp (초록은 두꺼운 테).
                      style: ink == Colors.white ? Skin.outlined(17) : Skin.bold(17, color: ink),
                      textAlign: TextAlign.center,
                      child: IconTheme.merge(
                        data: IconThemeData(color: ink),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 버튼 겉: 위 절반 광택 띠(스킨 r2 ③) + [shine]이 돌면 비스듬한 빛 줄기가 왼쪽→오른쪽으로 한 번.
class _Gloss extends StatelessWidget {
  const _Gloss({required this.child, this.shine});

  final Widget child;
  final Animation<double>? shine;

  @override
  Widget build(BuildContext context) => Stack(
    // 버튼 겉이 받은 크기 그대로(넓은 버튼은 꽉 차게) — 느슨하게 풀면 글자 크기로 줄어든다.
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned(
        left: 6,
        right: 6,
        top: 3,
        height: 12,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.42), Colors.white.withValues(alpha: 0)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      if (shine case final s?)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: s,
              builder: (context, _) {
                if (!s.isAnimating) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(Skin.radiusButton),
                  child: Align(
                    alignment: Alignment(-1.4 + 2.8 * Curves.easeInOut.transform(s.value), 0),
                    child: Transform.rotate(
                      angle: 0.4,
                      child: Container(
                        width: 16,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ],
  );
}
