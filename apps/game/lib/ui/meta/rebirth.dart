import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_chest.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_shop.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_why.dart';
import 'package:pirate_dot/ui/rebirth/treasure_route.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 상태 → 환생 미리보기 (경제 `rebirthPreview`, 사용자 결정 ①: 이번 회차 스테이지 기준). null이면 카드를 숨긴다(테스트용).
final rebirthPreviewProvider = Provider<RebirthPreview? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => rebirthPreview(s, tables);
});

/// 항해 탭의 환생 카드: 조각·보너스, 가능하면 이번 획득 조각과 보물지도 버튼, 아니면 해금 안내.
class RebirthCard extends ConsumerWidget {
  const RebirthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewOf = ref.watch(rebirthPreviewProvider);
    // RebirthPreview에는 ==가 없어서 화면에 쓰는 값만 레코드로 골라 구독한다.
    final view = ref.watch(
      gameStateProvider.select((s) {
        final p = previewOf(s);
        return p == null ? null : (p, s.progress.stage, p.locked, p.currentPieces, p.gain, p.nextPieceInStages);
      }),
    );
    if (view == null) return const SizedBox.shrink();
    final (preview, stage, _, _, _, _) = view;
    final l10n = AppLocalizations.of(context);
    final bonus = percentText(l10n, preview.bonusNow);
    final shopDot = ref.watch(rebirthShopProvider.select((s) => s.anyAffordable));
    final earned = ref.watch(gameStateProvider.select((s) => s.wallet.mapPieces));
    // 미리보기 계산은 카드가 다시 그려질 때만(스테이지·조각이 바뀔 때) — 틱마다 하지 않는다.
    final forecast = preview.locked ? null : ref.watch(rebirthForecastProvider)(ref.read(gameStateProvider));

    return PixelFrame(
      key: const Key('rebirth.card'),
      padding: 6,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkinIcon(UiSprites.tabMap),
                const SizedBox(width: 6),
                Text(l10n.uiRebirthTitle, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.uiRebirthPieces(preview.currentPieces, bonus)),
            const SizedBox(height: 8),
            if (!preview.locked) ...[
              Text(l10n.uiRebirthGain(preview.gain), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.uiRebirthNext(preview.nextPieceInStages)),
              if (forecast != null)
                Text(
                  forecastText(l10n, forecast),
                  key: const Key('rebirth.forecast'),
                  style: Skin.text(15, color: Skin.mintInk),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ShopButton(dot: shopDot),
                  // 첫 환생 전이면 손가락으로 길 안내(사용자 지시 2026-10-16).
                  TutorialSpot(
                    id: 'rebirth.open',
                    force: ref.watch(rebirthGuideProvider),
                    child: PixelButton(
                      key: const Key('rebirth.open'),
                      primary: true,
                      child: Text(l10n.uiRebirthButton),
                      onPressed: () {
                        markRebirthSeen(ref);
                        unawaited(
                          showDialog<void>(
                            context: context,
                            builder: (_) => RebirthDialog(preview: preview),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(l10n.uiRebirthLocked(preview.minStage)),
              // 해금 전에도 환생이 뭔지 한 줄로.
              Text(
                l10n.uiRebirthLockedWhy,
                key: const Key('rebirth.lockedWhy'),
                style: Skin.text(14, color: Skin.sub),
              ),
              const SizedBox(height: 4),
              PixelBar(value: (stage / preview.minStage).clamp(0.0, 1.0), fill: Skin.goldBottom),
              // 환생 전에도 조각이 있으면 상점을 볼 수 있다.
              if (earned > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ShopButton(dot: shopDot),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// '보물지도 상점' 버튼 — 살 수 있는 칸이 있으면 빨간 점 (스펙 7장 ①).
class _ShopButton extends StatelessWidget {
  const _ShopButton({required this.dot});

  final bool dot;

  @override
  Widget build(BuildContext context) => PixelDot(
    show: dot,
    dotKey: const Key('rebirth.shop.cardDot'),
    child: SkinButton(
      key: const Key('rebirth.shop.open'),
      tone: SkinTone.gold,
      onPressed: () => showRebirthShop(context),
      child: Text(AppLocalizations.of(context).uiRebirthShop),
    ),
  );
}

/// 환생 확인 창: 잃는 것 / 그대로인 것(+배 외형) / 얻는 것(+상자). 보물 바다가 열렸으면 항로 고르기. 되돌릴 수 없으니 한 번 더 누른다.
class RebirthDialog extends ConsumerWidget {
  const RebirthDialog({required this.preview, super.key});

  final RebirthPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final next = ref.watch(gameStateProvider.select((s) => s.progress.rebirths)) + 1;
    final chest = chestFor(next);
    return PixelDialog(
      title: l10n.uiRebirthTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 얻는 것 / 잃는 것 / 그대로 / 지금 vs 더 가고 (사용자 지시 2026-10-16).
            RebirthWhy(preview: preview),
            const SizedBox(height: 4),
            _Line(icon: UiSprites.gem, text: l10n.uiRebirthChestLine(chest.gems, chest.summons)),
            const TreasureRoute(),
          ],
        ),
      ),
      actions: [
        PixelButton(
          key: const Key('rebirth.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiCancel),
        ),
        PixelButton(
          key: const Key('rebirth.confirm'),
          primary: true,
          onPressed: () {
            ref.read(commandSinkProvider).send(const Rebirth());
            Navigator.of(context).pop();
          },
          child: Text(l10n.uiRebirthConfirm),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  /// 아이콘 그림 경로 (`UiSprites`).
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkinIcon(icon),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// 환생 결과 팝업 (‘조각 +N’). 이벤트가 아니라 상태로 안다: 환생 횟수가 늘면 그 사이 늘어난 지도 조각을 보인다.
class RebirthDoneGate extends ConsumerStatefulWidget {
  const RebirthDoneGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RebirthDoneGate> createState() => _RebirthDoneGateState();
}

class _RebirthDoneGateState extends ConsumerState<RebirthDoneGate> {
  StreamSubscription<RecordedTick>? _sub;

  /// 마지막으로 받은 RebirthDone (상자 내용: 젬·소환·칭호·스킨).
  RebirthDone? _done;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is RebirthDone) _done = e;
      }
    });
    ref.listenManual(gameStateProvider.select((s) => (s.progress.rebirths, s.wallet.mapPieces)), (before, after) {
      if (before == null || after.$1 <= before.$1) return;
      final gain = after.$2 - before.$2;
      final bonus = rebirthBonus(ref.read(gameStateProvider), ref.read(tablesProvider));
      // 상자 내용은 경제 이벤트 그대로. 이벤트를 못 받았으면(테스트·전장 없음) 같은 식으로 계산한 값.
      final e = _done;
      final chest = e != null && e.rebirths == after.$1
          ? (gems: e.gems, summons: e.summons, title: e.title, skin: e.skin)
          : chestFor(after.$1);
      final open = ref.read(rebirthChestOpenProvider.notifier)..opened();
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => RebirthChestDialog(
            chest: chest,
            pieces: e != null && e.rebirths == after.$1 ? e.gain : gain,
            bonus: percentText(AppLocalizations.of(context), bonus),
          ),
        ).whenComplete(open.closed),
      );
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
