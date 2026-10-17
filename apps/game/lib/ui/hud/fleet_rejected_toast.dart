import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show bossName;
import 'package:pirate_dot/ui/dex/monster_dex.dart';
import 'package:pirate_dot/ui/dex/monster_dex_data.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 편성이 거절되면(같은 계열 상한, 이벤트 FleetRejected)·환생 해금(ContentUnlocked)·도감 첫 처치(DexFirstKill) 때 안내를 띄운다. 이벤트는 렌더와 같은 스트림(battleFeedProvider)으로 온다.
class FleetRejectedToast extends ConsumerStatefulWidget {
  const FleetRejectedToast({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FleetRejectedToast> createState() => _FleetRejectedToastState();
}

class _FleetRejectedToastState extends ConsumerState<FleetRejectedToast> {
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        // 환생 v2 해금 안내 (스킨은 상자 팝업이 보여 주므로 따로 띄우지 않는다).
        if (e is ContentUnlocked && mounted) {
          final l10n = AppLocalizations.of(context);
          final text = switch (e.kind) {
            'crewMaxLevel' => l10n.uiCrewMaxLevelUp(e.value),
            'treasureSea' => l10n.uiUnlockTreasureSea(e.value),
            'shopRow' => l10n.uiUnlockShopRow(e.value),
            _ => null,
          };
          if (text != null) showSkinToast(context, text);
        }
        // 바다 괴물 첫 처치(경제 DexFirstKill): '새 괴물 도감 등록! 이름 · 젬 +n' + [도감].
        if (e is DexFirstKill && mounted) {
          final l10n = AppLocalizations.of(context);
          final name = e.boss ? bossName(l10n, ref, e.id) : monsterName(l10n, e.id);
          showSkinToast(
            context,
            e.gems > 0 ? l10n.uiDexNewGems(name, e.gems) : l10n.uiDexNew(name),
            action: l10n.uiDexTitleShort,
            onAction: () => unawaited(showMonsterDex(context)),
          );
        }
        if (e is FleetRejected && mounted) {
          final max = ref.read(tablesProvider).skills.maxSameFamilyInFleet;
          showSkinToast(context, AppLocalizations.of(context).uiFleetRejectedFamily(max));
        }
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
