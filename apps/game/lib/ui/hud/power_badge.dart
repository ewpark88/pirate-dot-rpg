import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/rolling_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 지금 함대 초당 공격력 (경제 `fleetPower(...).dps` — S1 결정 2026-10-16: 적 피해 숫자와 같은 단위).
/// 표시 글자가 바뀔 때만 다시 그린다(틱마다 작은 변화는 무시).
final fleetPowerProvider = Provider<BigNum>((ref) {
  final tables = ref.watch(tablesProvider);
  ref.watch(gameStateProvider.select((s) => fleetPower(s, tables).dps.format()));
  return fleetPower(ref.read(gameStateProvider), tables).dps;
});

/// 전투력이 오르면 초록 '+n'이 머무는 시간.
const powerGainFor = Duration(milliseconds: 1200);

/// 전투력 숫자가 굴러가는 시간 (S1 2026-10-17 '강화의 손맛').
const powerRollFor = Duration(milliseconds: 500);

/// 상단 바 골드·젬 옆 초당 공격력 (S1 지시 — 전장을 가리지 않게). 강화·합치기·편성으로 바뀔 때만 0.5초 굴러가고,
/// 오르면 초록 '+n'이 잠깐 (S1 2026-10-17). 전투 중 버프가 없는 값이라 틱마다 굴러가지 않는다(골드·젬은 롤링 없음).
class PowerBadge extends ConsumerStatefulWidget {
  const PowerBadge({super.key});

  @override
  ConsumerState<PowerBadge> createState() => _PowerBadgeState();
}

class _PowerBadgeState extends ConsumerState<PowerBadge> {
  BigNum? _last;
  String? _gain;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final power = ref.watch(fleetPowerProvider);
    final last = _last;
    if (last != null && power > last) {
      _gain = l10n.uiPowerGain((power - last).format());
      _hide?.cancel();
      _hide = Timer(powerGainFor, () {
        if (mounted) setState(() => _gain = null);
      });
    }
    _last = power;
    return Semantics(
      label: '${l10n.uiPower} ${power.format()}',
      excludeSemantics: true,
      child: Row(
        key: const Key('hud.power'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SkinIcon(UiSprites.part('cannon'), size: 16),
          const SizedBox(width: 3),
          // 숫자 위로 '+1.07K'가 떠오르며 사라진다(S1 실기기 2026-10-18 — 옆에 붙으면 숫자와 뭉쳐 보였다).
          Stack(
            clipBehavior: Clip.none,
            children: [
              RollingText(
                power.format(),
                textKey: const Key('hud.power.value'),
                style: Skin.outlined(15),
                duration: powerRollFor,
              ),
              if (_gain case final g?)
                Positioned(
                  left: 0,
                  bottom: 12,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(g),
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : powerGainFor,
                      builder: (_, t, child) => Transform.translate(
                        offset: Offset(0, -12 * t),
                        child: Opacity(opacity: (1 - t * t).clamp(0, 1).toDouble(), child: child),
                      ),
                      child: Text(
                        g,
                        key: const Key('hud.power.gain'),
                        softWrap: false,
                        style: Skin.outlined(12, color: const Color(0xFF8CF5B8)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
