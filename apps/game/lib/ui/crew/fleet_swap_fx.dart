import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

// 편성 교체 연출 (사용자 2026-10-18 '자동 편성 누르면 슬롯에 선원이 바뀐 연출을'): 칸의 출전 선원이 바뀌면 그 칸에서
// 나가는 선원이 아래로 쏙 빠지고 새 선원이 위에서 툭 떨어져 통통 착지 · 빛 고리 · 금빛 테 번쩍 · '교체!'(0.7초).
// 렌더가 칸 그림을 그리고, 이 층은 그 위에 잠깐 겹친다(누름 통과). 자동 편성으로 바뀐 게 없으면 '이미 최강 편성' 토스트.

const fleetSwapFor = Duration(milliseconds: 700);

class FleetSwapFx extends ConsumerStatefulWidget {
  const FleetSwapFx({required this.slot, super.key});

  final int slot;

  @override
  ConsumerState<FleetSwapFx> createState() => _FleetSwapFxState();
}

class _FleetSwapFxState extends ConsumerState<FleetSwapFx> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: fleetSwapFor);
  String? _out;
  String? _in;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tablesProvider);
    ref.listenManual(
      gameStateProvider.select((s) {
        final a = activeFleet(s, t);
        return widget.slot < a.length ? a[widget.slot] : null;
      }),
      (was, now) {
        if (now == null || was == now || !mounted) return;
        setState(() {
          _out = was;
          _in = now;
        });
        if (!MediaQuery.disableAnimationsOf(context)) unawaited(_c.forward(from: 0));
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tablesProvider);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating || _in == null) return const SizedBox.shrink();
          final v = _c.value;
          return LayoutBuilder(
            builder: (context, box) {
              final side = box.biggest.shortestSide;
              // 들어옴: 0~0.45 위에서 떨어짐(easeIn) → 0.45~0.7 통통 → 이후 제자리. 나감: 0~0.35 아래로 빠지며 흐려짐.
              final drop = v < 0.45 ? -side * (1 - Curves.easeIn.transform(v / 0.45)) : 0.0;
              final squash = v >= 0.45 && v < 0.7 ? 1 - 0.12 * Curves.easeOut.transform(1 - (v - 0.45) / 0.25) : 1.0;
              final glow = (1 - v).clamp(0, 1).toDouble();
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (_out != null && v < 0.35)
                    Transform.translate(
                      offset: Offset(0, side * 0.8 * (v / 0.35)),
                      child: Opacity(
                        opacity: 1 - v / 0.35,
                        child: CrewPortrait(crew: t.crews.byId(_out!), size: side * 0.8),
                      ),
                    ),
                  // 빛 고리(착지 순간부터 퍼짐).
                  if (v >= 0.45)
                    Container(
                      width: side * (0.6 + 0.8 * (v - 0.45) / 0.55),
                      height: side * (0.6 + 0.8 * (v - 0.45) / 0.55),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD84A).withValues(alpha: glow), width: 3),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, drop),
                    child: Transform.scale(
                      scaleX: 2 - squash,
                      scaleY: squash,
                      child: CrewPortrait(crew: t.crews.byId(_in!), size: side * 0.8),
                    ),
                  ),
                  // 금빛 테 번쩍.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD84A).withValues(alpha: glow), width: 3),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -18,
                    child: OutlineText(
                      AppLocalizations.of(context).uiFleetSwapped,
                      key: Key('fleet.swapped.${widget.slot}'),
                      size: 12,
                      tone: OutlineTone.gold,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 자동 편성: 보내고, 다음 상태에서 출전이 그대로면 '이미 최강 편성' 토스트.
void autoFleetWithFeedback(BuildContext context, WidgetRef ref) {
  final t = ref.read(tablesProvider);
  final before = activeFleet(ref.read(gameStateProvider), t).join(',');
  ref.read(fleetCommandsProvider).auto();
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!context.mounted) return;
      final after = activeFleet(ref.read(gameStateProvider), t).join(',');
      if (after == before) showSkinToast(context, AppLocalizations.of(context).uiFleetAlreadyBest);
    }),
  );
}
