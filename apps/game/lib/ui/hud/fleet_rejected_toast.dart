import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 편성이 거절되면(같은 계열 상한, 이벤트 FleetRejected) 안내를 띄운다. 이벤트는 렌더와 같은 스트림(battleFeedProvider)으로 온다.
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
