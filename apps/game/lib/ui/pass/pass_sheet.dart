import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/pass/pass_cells.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 항해 패스 (S2 iap.json pass · 경제 passOf·passLevel·canClaimPass · ClaimPassReward, 기획 economy-iap.md 3절):
// 항해 탭 카드(단계·경험치·받을 것 빨간 점) → 시트(단계 막대·얻는 법 · 패스 스킨 미리보기 · 무료/유료 두 줄 30칸 · 모두 받기 ·
// 유료 줄 열기 = 상점 voyage_pass). 받기는 차례대로(경제가 다음 칸만 준다) — 금빛 칸을 누르면 그 줄 다음 칸.

/// 받을 수 있는 칸 수(무료, 유료).
(int, int) passReady(GameState s, GameTables t, DateTime now) {
  final p = passOf(s, t);
  final lv = passLevel(s, t);
  final paidOn = entitlementActive(s, 'pass', now);
  return (lv - p.free, paidOn ? lv - p.paid : 0);
}

/// 항해 탭 카드 '항해 패스': 단계 n/30 · 막대 · 받을 것이 있으면 빨간 점.
class PassCard extends ConsumerWidget {
  const PassCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final now = ref.watch(clockProvider).now();
    // 패스·권리·최고 스테이지가 바뀔 때만 다시 그린다.
    ref.watch(gameStateProvider.select((s) => (s.pass, s.entitlements, s.progress.bestStage)));
    final state = ref.read(gameStateProvider);
    final lv = passLevel(state, t);
    final max = t.iap.pass.free.length;
    final (free, paid) = passReady(state, t, now);
    final xp = passOf(state, t).xp % t.iap.pass.xpPerLevel;
    return GestureDetector(
      key: const Key('pass.card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showPixelSheet<void>(context, maxHeight: 0.9, builder: (_) => const PassSheet())),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: Skin.inset(radius: Skin.radiusCard),
        child: Row(
          children: [
            PixelDot(
              dotKey: const Key('pass.dot'),
              show: free + paid > 0,
              child: const IconCell(
                color: Color(0xFFE0A83D),
                size: 52,
                child: SkinIcon(UiSprites.trophy, size: 36),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.uiPassTitle, style: Skin.bold(17)),
                  Text(l10n.uiPassLevel(lv, max), style: Skin.text(13, color: Skin.sub)),
                  const SizedBox(height: 4),
                  SkinBar(value: lv >= max ? 1 : xp / t.iap.pass.xpPerLevel, color: Skin.goldTop, height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PassSheet extends ConsumerWidget {
  const PassSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final pass = t.iap.pass;
    final now = ref.watch(clockProvider).now();
    final s = ref.watch(gameStateProvider);
    final p = passOf(s, t);
    final lv = passLevel(s, t);
    final paidOn = entitlementActive(s, 'pass', now);
    final (free, paid) = passReady(s, t, now);
    final sink = ref.read(commandSinkProvider);
    final until = s.entitlements['pass']?.until;
    // 패스 스킨이 있는 단계(미리보기).
    final skinAt = pass.paid.indexWhere((r) => r.skins.isNotEmpty);
    final offer = ref.watch(shopOffersProvider)[ShopSection.pass]?.firstOrNull;

    PassCellState stateOf(int i, {required bool paidRow}) {
      if (paidRow && !paidOn) return PassCellState.locked;
      if (i < (paidRow ? p.paid : p.free)) return PassCellState.claimed;
      return i < lv ? PassCellState.ready : PassCellState.ahead;
    }

    return Column(
      key: const Key('pass.sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SubRibbon(l10n.uiPassTitle),
        OnceTip(id: 'tip.pass', text: l10n.uiTipPass),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(l10n.uiPassLevel(lv, pass.free.length), style: Skin.bold(16)),
            const SizedBox(width: 8),
            Expanded(
              child: SkinBar(
                value: lv >= pass.free.length ? 1 : (p.xp % pass.xpPerLevel) / pass.xpPerLevel,
                color: Skin.goldTop,
              ),
            ),
            const SizedBox(width: 8),
            if (lv < pass.free.length)
              Text(l10n.uiPassNext(pass.xpPerLevel - p.xp % pass.xpPerLevel), style: Skin.text(12, color: Skin.sub)),
          ],
        ),
        Text(
          l10n.uiPassHow(pass.xp['quest'] ?? 0, pass.xp['stage'] ?? 0),
          style: Skin.text(12, color: Skin.sub),
        ),
        const SizedBox(height: 8),
        // 패스 스킨 미리보기 + 패스 상태(남은 일수 또는 열기).
        Container(
          padding: const EdgeInsets.all(8),
          decoration: Skin.inset(radius: Skin.radiusCard),
          child: Row(
            children: [
              if (skinAt >= 0) ...[
                ShipLookPreview(
                  key: const Key('pass.skinPreview'),
                  size: 84,
                  skin: pass.paid[skinAt].skins.first,
                  useSkin: true,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (skinAt >= 0) ...[
                      Text(l10n.uiPassSkinAt(skinAt + 1), style: Skin.text(12, color: Skin.sub)),
                      Text(l10n.uiPassSkinName, style: Skin.bold(16)),
                    ],
                    const SizedBox(height: 6),
                    if (paidOn && until != null)
                      Text(
                        l10n.uiPassActive(until.difference(now).inHours ~/ 24 + 1),
                        key: const Key('pass.active'),
                        style: Skin.bold(14, color: Skin.mintInk),
                      )
                    else if (offer != null)
                      SkinButton(
                        key: const Key('pass.unlock'),
                        tone: SkinTone.gold,
                        height: 44,
                        onPressed: () => buyProduct(ref, offer.product.id),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.uiPassUnlock(offer.price)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 두 줄 30칸: 위 무료, 아래 유료. 지금 단계 근처로 처음 굴린다.
        SizedBox(
          height: 170,
          child: ListView.builder(
            key: const Key('pass.track'),
            scrollDirection: Axis.horizontal,
            controller: ScrollController(initialScrollOffset: ((lv - 2).clamp(0, pass.free.length) * 70).toDouble()),
            itemCount: pass.free.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                children: [
                  Text((i + 1).toString(), style: Skin.bold(13, color: i < lv ? Skin.goldInk : Skin.sub)),
                  const SizedBox(height: 4),
                  PassCell(
                    key: Key('pass.free.$i'),
                    reward: pass.free[i],
                    state: stateOf(i, paidRow: false),
                    paid: false,
                    onTap: () => sink.send(const ClaimPassReward(paid: false)),
                  ),
                  const SizedBox(height: 6),
                  PassCell(
                    key: Key('pass.paid.$i'),
                    reward: pass.paid[i],
                    state: stateOf(i, paidRow: true),
                    paid: true,
                    onTap: () => sink.send(const ClaimPassReward(paid: true)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SkinButton(
          key: const Key('pass.claimAll'),
          height: 52,
          onPressed: free + paid == 0
              ? null
              : () {
                  for (var i = 0; i < free; i++) {
                    sink.send(const ClaimPassReward(paid: false));
                  }
                  for (var i = 0; i < paid; i++) {
                    sink.send(const ClaimPassReward(paid: true));
                  }
                },
          child: Text(l10n.uiPassClaimAll),
        ),
      ],
    );
  }
}
