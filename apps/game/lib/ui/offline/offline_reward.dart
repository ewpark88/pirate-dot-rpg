import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상태·지금 시각 → 복귀 보상 미리보기 (경제 `offlinePreview`, ClaimOffline과 같은 계산). null이면 팝업 없음(최소 시간 미만).
final offlinePreviewProvider = Provider<OfflinePreview? Function(GameState state, DateTime now)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s, now) => offlinePreview(s, tables, now);
});

/// 앱 시작 첫 프레임과 백그라운드 복귀 때 오프라인 보상 팝업을 1개만 띄운다 (설계서 4.7, 4.9 ‘접속 때 팝업 최대 1개’).
class OfflineRewardGate extends ConsumerStatefulWidget {
  const OfflineRewardGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineRewardGate> createState() => _OfflineRewardGateState();
}

class _OfflineRewardGateState extends ConsumerState<OfflineRewardGate> {
  late final AppLifecycleListener _lifecycle;
  var _open = false;

  @override
  void initState() {
    super.initState();
    // 복귀: main이 EngineHost.resume()으로 savedAt을 멈춘 시각에 맞춘 뒤, 다음 프레임에 미리보기를 구한다.
    _lifecycle = AppLifecycleListener(onResume: _checkNextFrame);
    _checkNextFrame();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 다음 프레임에 확인한다. 복귀 직후에는 그릴 것이 없어 프레임이 안 올 수 있으니 직접 요청한다.
  void _checkNextFrame() => WidgetsBinding.instance
    ..addPostFrameCallback((_) => unawaited(_check()))
    ..ensureVisualUpdate();

  Future<void> _check() async {
    if (_open || !mounted) return;
    final preview = ref.read(offlinePreviewProvider)(ref.read(gameStateProvider), ref.read(clockProvider).now());
    if (preview == null) return;
    _open = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OfflineRewardDialog(preview: preview),
    );
    _open = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 오프라인 보상 팝업: 경과 시간·골드·카드, 받기 → ClaimOffline.
class OfflineRewardDialog extends ConsumerStatefulWidget {
  const OfflineRewardDialog({required this.preview, super.key});

  final OfflinePreview preview;

  @override
  ConsumerState<OfflineRewardDialog> createState() => _OfflineRewardDialogState();
}

class _OfflineRewardDialogState extends ConsumerState<OfflineRewardDialog> {
  /// 받기를 눌렀나. 광고 ×2는 받은 뒤(`lastOfflineGold`)에만 있으므로, 광고가 준비됐으면 창을 열어 둔다.
  var _claimed = false;

  void _claim() {
    ref.read(commandSinkProvider).send(const ClaimOffline());
    if (ref.read(adsPortProvider).isReady(AdPlacement.offline)) {
      setState(() => _claimed = true);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = widget.preview;
    final away = Duration(seconds: preview.seconds);
    return AlertDialog(
      title: Text(l10n.uiOfflineTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.uiOfflineElapsed(away.inHours, away.inMinutes % Duration.minutesPerHour)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PixelSprite(UiSprites.coin, dots: 16, scale: 1),
              const SizedBox(width: 6),
              Text(preview.gold.format(), style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          if (preview.cards > 0) Text(l10n.uiCrewCards(preview.cards)),
        ],
      ),
      actions: [
        if (_claimed) ...[
          // 광고 ×2 (설계서 4.6: 복귀당 1회) — 경제가 허락하고 광고가 준비됐을 때만 보인다.
          const OfflineAdButton(),
          TextButton(
            key: const Key('offline.ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.uiOk),
          ),
        ] else
          PixelButton(
            key: const Key('offline.claim'),
            primary: true,
            onPressed: _claim,
            child: Text(l10n.uiOfflineClaim),
          ),
      ],
    );
  }
}
