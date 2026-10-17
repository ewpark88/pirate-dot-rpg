import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/hud/hud_layout.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 운영자 패널 ‘렌더’ 묶음: 전장 모드(라이브·데모·부하), 성능 표시, 히트박스, 카드 연출 시작 등급(피드백 #22).
/// 렌더 레인의 BattleGame 공개 API만 부른다. 전장이 Flame 게임이 아니면(테스트의 빈 상자) 비활성.
class RenderGroup extends ConsumerStatefulWidget {
  const RenderGroup({super.key});

  @override
  ConsumerState<RenderGroup> createState() => _RenderGroupState();
}

class _RenderGroupState extends ConsumerState<RenderGroup> {
  /// 카드 앞면 공개 연출 시작 등급 — BattleGame은 setter만 있어 여기서 기억한다(처음은 fx_map cardFx.minRarity).
  String? _cardFx;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(hasBattleGameProvider) ? ref.watch(battleGameProvider) : null;

    final tables = ref.watch(tablesProvider);
    final cardFx = _cardFx ?? tables.fxMap.raw.obj('cardFx').str('minRarity');
    // 일반·희귀·영웅·전설 (신화는 승급으로만 — 소환 카드에 안 나온다).
    final rarities = tables.rarities.rarities.where((r) => r.summonRate > 0).toList();

    // BattleGame 값은 GameState가 아니라서, 바꾼 뒤 setState로 다시 그린다.
    void apply(void Function(BattleGame g) change) => setState(() => change(game!));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<BattleMode>(
          key: const Key('op.mode'),
          segments: [
            ButtonSegment(value: BattleMode.live, label: Text(l10n.opModeLive)),
            ButtonSegment(value: BattleMode.demo, label: Text(l10n.opModeDemo)),
            ButtonSegment(value: BattleMode.stress, label: Text(l10n.opModeStress)),
          ],
          selected: {?game?.mode},
          emptySelectionAllowed: true,
          onSelectionChanged: game == null
              ? null
              : (s) => apply(
                  (g) => switch (s.single) {
                    BattleMode.live => g.resumeLive(),
                    BattleMode.demo => g.loadDemo(),
                    BattleMode.stress => g.loadStress(),
                  },
                ),
        ),
        FilterChip(
          key: const Key('op.perfOverlay'),
          label: Text(l10n.opPerfOverlay),
          selected: game?.perfOverlay ?? false,
          onSelected: game == null ? null : (on) => apply((g) => g.perfOverlay = on),
        ),
        FilterChip(
          key: const Key('op.hitboxes'),
          label: Text(l10n.opHitboxes),
          selected: game?.showHitboxes ?? false,
          onSelected: game == null ? null : (on) => apply((g) => g.showHitboxes = on),
        ),
        Text(l10n.opCardFxMin),
        SegmentedButton<String>(
          key: const Key('op.cardFxMin'),
          segments: [for (final r in rarities) ButtonSegment(value: r.id, label: Text(tableText(l10n, r.nameKey)))],
          selected: {cardFx},
          onSelectionChanged: game == null
              ? null
              : (s) => apply((g) {
                  _cardFx = s.single;
                  g.cardFxMinRarity = s.single;
                }),
        ),
        // HUD 배치 안(사용자 '상태바·메뉴바 위치 검토') — 폰에서 바로 바꿔 본다.
        Text(l10n.opHudLayout),
        SegmentedButton<HudLayout>(
          key: const Key('op.hudLayout'),
          segments: [
            ButtonSegment(value: HudLayout.now, label: Text(l10n.opHudNow)),
            ButtonSegment(value: HudLayout.thumb, label: Text(l10n.opHudThumb)),
            ButtonSegment(value: HudLayout.floating, label: Text(l10n.opHudFloating)),
            ButtonSegment(value: HudLayout.slim, label: Text(l10n.opHudSlim)),
          ],
          selected: {ref.watch(hudLayoutProvider)},
          onSelectionChanged: (s) => ref.read(hudLayoutProvider.notifier).pick(s.single),
        ),
        // 유료 상점 골격(결제 전 가짜 목록) — 운영자만 연다.
        OutlinedButton(
          key: const Key('op.shop'),
          onPressed: () => unawaited(showShop(context)),
          child: Text(l10n.uiShopOpen),
        ),
      ],
    );
  }
}
