import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/offline/notify_ask.dart';
import 'package:pirate_dot/ui/offline/offline_fx.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/widgets/reward_fly.dart' show flyRewards;

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

  /// 이미 띄운 복귀(savedAt) — 시작과 복귀 신호가 겹쳐도 같은 복귀는 한 번만(S1 실기기 ①).
  DateTime? _shownFor;

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
    final state = ref.read(gameStateProvider);
    if (state.savedAt == _shownFor) return;
    final preview = ref.read(offlinePreviewProvider)(state, ref.read(clockProvider).now());
    if (preview == null) return;
    _open = true;
    _shownFor = state.savedAt;
    await showSkinDialog<void>(
      context,
      barrierDismissible: false,
      builder: (_) => OfflineRewardDialog(preview: preview),
    );
    _open = false;
    // 복귀 보상을 받은 직후가 알림 권한을 묻기 좋은 때(첫 실행 즉시가 아니라 — S1 2026-10-18).
    if (mounted) await maybeAskNotify(context);
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

  /// 받을 때 보인 양 — 받은 뒤에도 그대로 둔다(명령은 다음 틱에 처리되므로 바로 읽으면 0 · 전부 잘림으로 보였다, S1 실기기 ①).
  BigNum? _received;

  /// 실릴 몫 = min(계산값, 오프라인 상한(화물칸 × capMultiplier) − 지금 골드) — 경제 claimOffline과 같은 계산(실기기 ②).
  BigNum _fits() {
    final s = ref.read(gameStateProvider);
    final t = ref.read(tablesProvider);
    final room = goldRoom(s, t, capScale: offlineCapScale(t, s)); // 환생 직후 바닥값(다음 강화 floorUpgrades번)도 같이
    return widget.preview.gold > room ? room : widget.preview.gold;
  }

  void _claim() {
    _received = _fits();
    ref.read(commandSinkProvider).send(const ClaimOffline());
    // 금화 비 → 위 막대 금화 자리로 날아가 꽂힌다(받을 게 있을 때).
    if (!_received!.isZero) flyRewards(context, List.filled(5, UiSprites.coin));
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
    // 오프라인 상한까지만 실린다(S2 economy-cargo-capacity · capMultiplier), 잘린 몫 = 나머지.
    final got = _received ?? _fits();
    final cut = preview.gold > got ? preview.gold - got : BigNum.zero;
    return PixelDialog(
      title: l10n.uiOfflineTitle,
      // 받기 버튼으로만 닫는다(바깥 눌러도 안 닫힘).
      showClose: false,
      icon: const SkinIcon(UiSprites.moon, size: 56),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.uiOfflineElapsed(away.inHours, away.inMinutes % Duration.minutesPerHour),
            textAlign: TextAlign.center,
            style: Skin.bold(16),
          ),
          const SizedBox(height: 10),
          // 밤하늘 판(별이 차례로 반짝) + 금화 칸 + 0부터 굴러 오르는 금빛 숫자(S1 2026-10-18 HD 결).
          NightSkyPanel(
            key: const Key('offline.gold'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const IconCell(color: Color(0xFFE0A83D), size: 52, child: SkinIcon(UiSprites.coin, size: 38)),
                const SizedBox(width: 10),
                Flexible(
                  child: RewardSparkle(child: RollUpGold(value: got)),
                ),
              ],
            ),
          ),
          if (!cut.isZero) ...[
            const SizedBox(height: 6),
            Text(
              l10n.uiOfflineCut(cut.format()),
              key: const Key('offline.cut'),
              textAlign: TextAlign.center,
              style: Skin.text(14, color: Skin.danger),
            ),
            const SizedBox(height: 6),
            SkinButton(
              key: const Key('offline.cargo'),
              tone: SkinTone.gold,
              height: 44,
              onPressed: () {
                if (!_claimed) ref.read(commandSinkProvider).send(const ClaimOffline());
                Navigator.of(context).pop();
                ref.read(dockTabRequestProvider.notifier).open(shipTabIndex);
              },
              child: Text(l10n.uiCargoUpgrade),
            ),
          ],
          if (preview.cards > 0) Text(l10n.uiCrewCards(preview.cards)),
        ],
      ),
      actions: [
        if (_claimed) ...[
          // 광고 ×2 (설계서 4.6: 복귀당 1회) — 경제가 허락하고 광고가 준비됐을 때만. 받은 골드가 0이면(화물칸 가득)
          // '×2 · +0'이 되므로 숨긴다(S1 실기기 ②) — 그때 첫 버튼은 위 [화물칸 강화].
          if (!got.isZero) const OfflineAdButton(),
          PixelButton(
            key: const Key('offline.ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.uiOk),
          ),
        ] else
          PixelButton(
            key: const Key('offline.claim'),
            // 받을 게 0이면(화물칸 가득) [화물칸 강화]가 주 버튼.
            primary: !got.isZero,
            onPressed: _claim,
            child: Text(l10n.uiOfflineClaim),
          ),
      ],
    );
  }
}
