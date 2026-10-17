import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 보스 브레이크 (사용자 결정 2026-10-17, specs/platform-fever-break.md 2): 기절·둔화·취약·밀림이 쌓이는 막대 +
// 가득 차 쓰러지는 순간 'BREAK!'. 쓰러짐 그림·큰 피해 숫자는 렌더(S3), 수치는 skills.json bossBreak(S2).

/// 'BREAK!' 글자가 떠 있는 시간.
const _burst = Duration(milliseconds: 1400);

/// 보스 시간 막대 아래 얇은 브레이크 막대. 쓰러진 동안은 금빛으로 가득 + 'BREAK!'.
/// 보스가 없거나 표가 꺼져(게이지가 한 번도 안 참) 0이면 자리만 지킨다 — 게이지 높이가 흔들리지 않게.
class BossBreakBar extends ConsumerWidget {
  const BossBreakBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (ratio, broken) = ref.watch(
      gameStateProvider.select((s) {
        for (final e in s.battle?.enemies ?? const <EnemyView>[]) {
          if (e.boss) return ((e.breakRatio * 20).round() / 20, e.broken);
        }
        return (0.0, false);
      }),
    );
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: broken ? l10n.uiBossBreak : l10n.uiBossBreakGauge((ratio * 100).round()),
      excludeSemantics: true,
      child: Row(
        key: const Key('hud.break'),
        children: [
          Text(l10n.uiBossBreakTag, style: Skin.text(10, color: broken ? const Color(0xFFFFD84A) : Colors.white70)),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.white24),
                    FractionallySizedBox(
                      key: Key(broken ? 'hud.break.full' : 'hud.break.fill'),
                      alignment: Alignment.centerLeft,
                      widthFactor: broken ? 1 : ratio.clamp(0.0, 1.0),
                      child: ColoredBox(color: broken ? const Color(0xFFFFD84A) : const Color(0xFF7FD6FF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 보스가 쓰러지는 순간(BossBroken) 보스 자리에 'BREAK!' — 누름 통과. 전장 좌표는 ChestLayer와 같은 카메라로 dp에 놓는다.
class BossBreakBurst extends ConsumerStatefulWidget {
  const BossBreakBurst({super.key});

  @override
  ConsumerState<BossBreakBurst> createState() => _BossBreakBurstState();
}

class _BossBreakBurstState extends ConsumerState<BossBreakBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  StreamSubscription<RecordedTick>? _sub;
  Offset? _at;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: _burst);
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is BossBroken && mounted) show(Offset(e.x, e.y));
      }
    });
  }

  /// [world] = 쓰러진 보스의 전장 좌표 (테스트도 부른다).
  @visibleForTesting
  void show(Offset world) {
    setState(() => _at = world);
    unawaited(
      _ctl.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _at = null);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = _at;
    if (world == null) return const SizedBox.shrink();
    final shipY = ref.read(gameStateProvider).battle?.shipY ?? 240;
    final shipX = ref.read(tablesProvider).waves.top.shipX;
    final calm = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final game = ref.watch(hasBattleGameProvider) ? ref.read(battleGameProvider) : null;
          final at = game != null && game.hasLayout
              ? game.worldToDp(world)
              : topFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context)).worldToDp(world, Offset(shipX, shipY));
          // 글자가 상자 밖으로 나가지 않게 가로·세로를 안쪽으로 당긴다(360dp에서도 한 줄).
          final x = at.dx.clamp(64.0, (box.maxWidth - 64).clamp(64.0, double.infinity));
          final y = at.dy.clamp(40.0, (box.maxHeight - 40).clamp(40.0, double.infinity));
          return Stack(
            children: [
              Positioned(
                left: x - 80,
                top: y - 56,
                width: 160,
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (context, child) {
                    final t = _ctl.value;
                    // 0~0.15 커지며 등장 → 머묾 → 0.75부터 위로 사라짐.
                    final pop = calm
                        ? 1.0
                        : (t < 0.15 ? 0.6 + 0.6 * (t / 0.15) : (t < 0.25 ? 1.2 - 2 * (t - 0.15) : 1.0));
                    final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, calm ? 0 : -12 * (t > 0.75 ? (t - 0.75) / 0.25 : 0)),
                        child: Transform.scale(scale: pop, child: child),
                      ),
                    );
                  },
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context).uiBossBreak,
                        key: const Key('hud.break.burst'),
                        maxLines: 1,
                        style: Skin.text(26, color: const Color(0xFFFFD84A)).copyWith(
                          shadows: const [
                            Shadow(color: Color(0xFF1B2A4A), offset: Offset(2, 2)),
                            Shadow(color: Color(0xFFD7263D), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
