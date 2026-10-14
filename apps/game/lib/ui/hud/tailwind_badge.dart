import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 남은 시간을 다시 그리는 주기.
const _tick = Duration(seconds: 1);

/// 흐린 아이콘의 불투명도 (순풍 없음).
const _inactiveOpacity = 0.4;

/// 순풍 버프 표시 (설계서 4.6): 켜져 있으면 남은 시간과 배율, 아니면 흐린 돛 아이콘.
// TODO(ui): 누르면 ‘광고 보고 30분 ×2’ 버튼 — 광고 포트(AdsPort)가 생기면. 로드 안 되면 숨김.
class TailwindBadge extends ConsumerStatefulWidget {
  const TailwindBadge({super.key});

  @override
  ConsumerState<TailwindBadge> createState() => _TailwindBadgeState();
}

class _TailwindBadgeState extends ConsumerState<TailwindBadge> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // 상태가 바뀌지 않아도 남은 시간은 줄어든다 → 1초마다 다시 그린다.
    _timer = Timer.periodic(_tick, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    // 남은 시간은 경제 tailwindRemaining (끝났으면 zero).
    final left = ref.watch(gameStateProvider.select((s) => tailwindRemaining(s, now)));
    final active = left > Duration.zero;
    final multiplier = ref
        .watch(tablesProvider)
        .ads
        .placements
        .firstWhere((p) => p.id == 'tailwind')
        .reward
        .number('goldMultiplier');

    return Container(
      key: const Key('tailwind'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Opacity(
        opacity: active ? 1 : _inactiveOpacity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sailing, color: Colors.white, size: 16),
            if (active) ...[
              const SizedBox(width: 4),
              Text(remainingText(left), style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 4),
              Text(
                l10n.uiEffectMultiplier(shortDecimal(multiplier)),
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
