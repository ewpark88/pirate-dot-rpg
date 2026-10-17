import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart' show audioPortProvider;
import 'package:pirate_dot/ui/state/game_providers.dart';

// 누름 반응 통일 (S1 2026-10-18): 모든 버튼·칸이 같은 손맛 — 눌림 스쿼시 · 소리(가벼운 '톡' / 큰 동작 '퉁') ·
// 진동(설정 진동 켜짐일 때: 보통 light, 구매·환생·소환 같은 큰 동작만 medium) · 못 누르면 좌우 흔들림 + '부족해요' 소리.
// SkinButton은 이걸 쓰고, 버튼이 아닌 칸(도크 아이콘·카드)은 [Pressable]로 감싼다.

/// 누름 무게: 보통(톡·light) / 큰 동작(퉁·medium).
enum PressWeight { light, heavy }

ProviderContainer? _containerOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false);
  } on Object {
    return null; // 앱 밖(단독 위젯 테스트)에서는 소리·진동 없음.
  }
}

/// 눌렀을 때 소리·진동.
void pressFeel(BuildContext context, PressWeight weight, {bool sound = true}) {
  final c = _containerOf(context);
  if (c == null) return;
  if (sound) {
    c.read(audioPortProvider)?.playSfx('pop', pitch: weight == PressWeight.heavy ? 0.85 : 1.6);
  }
  if (c.read(gameStateProvider).settings.vibration) {
    (weight == PressWeight.heavy ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact()).ignore();
  }
}

/// 못 누르는 것을 눌렀을 때: '부족해요' 소리(낮은 fail) + 가벼운 진동. 흔들림은 위젯이.
void deniedFeel(BuildContext context) {
  final c = _containerOf(context);
  if (c == null) return;
  c.read(audioPortProvider)?.playSfx('fail', pitch: 1.3);
  if (c.read(gameStateProvider).settings.vibration) HapticFeedback.lightImpact().ignore();
}

/// 좌우 흔들림 값(0~1 진행 → 픽셀). 세 번 흔들리며 잦아든다.
double shakeOffset(double t) => t <= 0 || t >= 1 ? 0 : math.sin(t * math.pi * 6) * 6 * (1 - t);

/// 버튼이 아닌 누르는 칸: 눌림 스쿼시(0.94) + 놓으면 통 + [pressFeel]. [onTap]이 null이면 누를 때 흔들림 + [deniedFeel]
/// ([onDenied]가 있으면 그것도 부른다 — '젬이 부족해요' 토스트 등).
class Pressable extends StatefulWidget {
  const Pressable({
    required this.onTap,
    required this.child,
    this.weight = PressWeight.light,
    this.onDenied,
    this.sound = true,
    this.deniable = true,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;
  final PressWeight weight;
  final VoidCallback? onDenied;

  /// 소리를 낼지(이미 자기 소리가 있는 칸은 끈다).
  final bool sound;

  /// [onTap]이 null일 때 흔들릴지(그냥 꺼진 칸이면 false).
  final bool deniable;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with TickerProviderStateMixin {
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
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void dispose() {
    _press.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _denied() {
    deniedFeel(context);
    if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0).ignore();
    widget.onDenied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              pressFeel(context, widget.weight, sound: widget.sound);
              _press.forward().ignore();
            }
          : null,
      onTapCancel: enabled ? _press.reverse : null,
      onTapUp: enabled ? (_) => _press.reverse() : null,
      onTap: enabled ? widget.onTap : (widget.deniable ? _denied : null),
      child: AnimatedBuilder(
        animation: Listenable.merge([_t, _shake]),
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(shakeOffset(_shake.value), 0),
          child: Transform.scale(scale: 1 - 0.06 * _t.value, child: child),
        ),
      ),
    );
  }
}
