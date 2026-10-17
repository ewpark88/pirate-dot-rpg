import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
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

/// 상단 바 골드·젬 옆 초당 공격력 (S1 지시 — 전장을 가리지 않게). 사용자 지시(골드와 같은 원칙): 숫자만 조용히 바뀐다.
class PowerBadge extends ConsumerWidget {
  const PowerBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final power = ref.watch(fleetPowerProvider);
    return Semantics(
      label: '${AppLocalizations.of(context).uiPower} ${power.format()}',
      excludeSemantics: true,
      child: Row(
        key: const Key('hud.power'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkinIcon('assets/ui/part_cannon.png', size: 16),
          const SizedBox(width: 3),
          Text(power.format(), key: const Key('hud.power.value'), style: Skin.outlined(15, stroke: 1.2)),
        ],
      ),
    );
  }
}
