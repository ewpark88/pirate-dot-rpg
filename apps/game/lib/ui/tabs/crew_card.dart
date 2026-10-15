import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';

/// 승급 버튼을 보이는 상태 = 승급 문 앞(레벨은 됐고 카드·골드·증표만 남음).
const Set<PromoteStatus> _atGate = {PromoteStatus.ok, PromoteStatus.cards, PromoteStatus.gold, PromoteStatus.tokens};

/// 선원 한 명 (스킨 r1): Pirate Busters 카드(등급 테두리·일러스트·별 리본·이름), 레벨·카드 수 배지,
/// 승급(문 앞일 때 오른쪽 아래 작은 원 버튼), 출전이면 아래 민트 알약. 미보유는 실루엣. 누르면 상세 창.
class CrewCard extends ConsumerWidget {
  const CrewCard({required this.def, required this.owned, super.key});

  final CrewDef def;
  final bool owned;

  String get crewId => def.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (level, cards, status) = ref.watch(
      gameStateProvider.select((s) {
        final crew = s.crews[def.id];
        return (crew?.level, crew?.cards, promoteStatus(s, tables, def.id));
      }),
    );
    final deployed = ref.watch(fleetSlotsProvider.select((slots) => slots.contains(def.id)));
    final rarity = level == null ? tables.rarities.byId(def.baseRarity) : rarityOfLevel(tables.rarities, level);

    return GestureDetector(
      key: Key('crew.card.${def.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showCrewDetail(context, def)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PbCardFront(
                key: Key('crew.name.${def.id}'),
                crew: def,
                rarity: rarity,
                name: shortCrewName(l10n, def),
                silhouette: !owned,
                topLeft: level == null ? null : PbBadge(l10n.uiLevel(level), key: Key('crew.level.${def.id}')),
                topRight: cards == null || cards == 0
                    ? null
                    : PbBadge(
                        l10n.uiCrewCardBadge(cards),
                        key: Key('crew.cards.${def.id}'),
                        color: Skin.goldBottom,
                        ink: Skin.goldInk,
                      ),
              ),
              if (_atGate.contains(status))
                Positioned(
                  right: -4,
                  bottom: -4,
                  width: kMinTap,
                  height: kMinTap,
                  child: _PromoteButton(crewId: def.id, ready: status == PromoteStatus.ok),
                ),
            ],
          ),
          if (deployed)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFE8F8EF), borderRadius: BorderRadius.circular(10)),
                  child: Text(l10n.uiCrewDeployed, style: Skin.text(13, color: Skin.mintInk)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoteButton extends ConsumerWidget {
  const _PromoteButton({required this.crewId, required this.ready});

  final String crewId;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = AppLocalizations.of(context).uiCrewPromote;
    final button = Tooltip(
      message: label,
      child: PixelButton(
        key: Key('crew.promote.$crewId'),
        primary: true,
        compact: true,
        semanticLabel: label,
        onPressed: ready ? () => ref.read(commandSinkProvider).send(PromoteCrew(crewId)) : null,
        child: PixelBitmap(PixelBitmaps.up, color: ready ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
    if (!ready) return button;
    // 빨간 점은 지금 눌러서 이득일 때만 (설계서 4.9) — 도트 네모 점.
    return Stack(
      children: [
        Positioned.fill(child: button),
        Positioned(
          right: 0,
          bottom: 22,
          child: SizedBox(
            key: Key('crew.dot.$crewId'),
            width: 6,
            height: 6,
            child: const ColoredBox(color: PixelPalette.danger),
          ),
        ),
      ],
    );
  }
}
