import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/guide/guide_spots.dart';
import 'package:pirate_dot/ui/hud/coin_arrival.dart' show topGoldIconKey;
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 보상 끝맺음 (S1 2026-10-18 '보상 쾌감 핵심'): 보상 터짐 창이 닫히면 칸마다 아이콘이 위 막대 제 자리로 곡선을 그리며 날아가
// 꽂히고, 그 숫자가 통통 튀며 반짝인다. 젬 → 젬 아이콘, 골드 → 금화 아이콘, 카드·소환 → 도크 선원 탭.

/// 위 막대 젬 아이콘 자리(날아갈 곳).
final GlobalKey topGemIconKey = GlobalKey(debugLabel: 'top.gem.icon');

/// 날아가는 시간 · 칸 사이 늦춤.
const rewardFlyFor = Duration(milliseconds: 650);
const _stagger = Duration(milliseconds: 70);

/// 꽂힌 자리 — 숫자 통통(번호가 바뀔 때마다 다시).
enum RewardSlot { gold, gem, crew }

final rewardBumpProvider = NotifierProvider<RewardBump, Map<RewardSlot, int>>(RewardBump.new);

class RewardBump extends Notifier<Map<RewardSlot, int>> {
  @override
  Map<RewardSlot, int> build() => const {};

  void hit(RewardSlot slot) => state = {...state, slot: (state[slot] ?? 0) + 1};
}

RewardSlot rewardSlotOf(String icon) => switch (icon) {
  UiSprites.gem => RewardSlot.gem,
  UiSprites.coin => RewardSlot.gold,
  _ => RewardSlot.crew,
};

Rect? _rectOfKey(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

Rect? _target(RewardSlot slot) => switch (slot) {
  RewardSlot.gold => _rectOfKey(topGoldIconKey),
  RewardSlot.gem => _rectOfKey(topGemIconKey),
  RewardSlot.crew => guideSpotRects(['tab.crew']).firstOrNull,
};

/// [icons]를 화면 가운데 줄에서 각자 자리로 날린다(애니메이션 줄이기면 바로 통통만).
void flyRewards(BuildContext context, List<String> icons) {
  final bump = ProviderScope.containerOf(context, listen: false).read(rewardBumpProvider.notifier);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || icons.isEmpty) return;
  final calm = MediaQuery.disableAnimationsOf(context);
  final size = MediaQuery.sizeOf(context);
  for (final (i, icon) in icons.indexed) {
    final slot = rewardSlotOf(icon);
    final to = _target(slot);
    if (calm || to == null) {
      bump.hit(slot);
      continue;
    }
    final from = Offset(size.width / 2 + (i - (icons.length - 1) / 2) * 72, size.height * 0.5);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Flyer(
        icon: icon,
        from: from,
        to: to.center,
        delay: _stagger * i,
        onArrive: () {
          if (entry.mounted) entry.remove();
          bump.hit(slot);
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _Flyer extends StatefulWidget {
  const _Flyer({required this.icon, required this.from, required this.to, required this.delay, required this.onArrive});

  final String icon;
  final Offset from;
  final Offset to;
  final Duration delay;
  final VoidCallback onArrive;

  @override
  State<_Flyer> createState() => _FlyerState();
}

class _FlyerState extends State<_Flyer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: rewardFlyFor);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () {
      if (mounted) unawaited(_c.forward().then((_) => widget.onArrive()));
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(_c.value);
        // 위로 휘는 곡선(가운데가 위로 솟는다).
        final p = Offset.lerp(widget.from, widget.to, t)! + Offset(0, -math.sin(t * math.pi) * 60);
        final s = 1.1 - 0.5 * t;
        return Stack(
          children: [
            Positioned(
              left: p.dx - 20,
              top: p.dy - 20,
              child: Transform.scale(scale: s, child: SkinIcon(widget.icon, size: 40)),
            ),
          ],
        );
      },
    ),
  );
}

/// 위 막대 숫자를 감싼다: 이 자리에 보상이 꽂히면 1.35배로 통통 + 금빛 반짝(0.35초).
class RewardBumpTarget extends ConsumerWidget {
  const RewardBumpTarget({required this.slot, required this.child, super.key});

  final RewardSlot slot;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(rewardBumpProvider.select((m) => m[slot] ?? 0));
    if (n == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(n),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 350),
      builder: (_, k, c) => Transform.scale(
        scale: 1 + 0.35 * Curves.easeOut.transform(k),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: k > 0
                ? [BoxShadow(color: const Color(0xFFFFD84A).withValues(alpha: 0.8 * k), blurRadius: 12)]
                : null,
          ),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
