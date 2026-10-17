import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 승급 버튼을 보이는 상태 = 승급 문 앞(레벨은 됐고 카드·골드·증표만 남음).
const Set<PromoteStatus> _atGate = {PromoteStatus.ok, PromoteStatus.cards, PromoteStatus.gold, PromoteStatus.tokens};

/// 선원 한 명 (스킨 r1): Pirate Busters 카드(등급 테두리·일러스트·별 리본·이름), 레벨·카드 수 배지,
/// 승급(문 앞일 때 오른쪽 아래 작은 원 버튼), 출전이면 아래 민트 알약. 미보유는 실루엣. 누르면 상세 창.
class CrewCard extends ConsumerWidget {
  const CrewCard({required this.def, required this.owned, this.levelUpSpot = false, super.key});

  final CrewDef def;
  final bool owned;

  /// 목록에서 처음으로 합칠 수 있는 선원 — 가이드 카드가 가리키는 TutorialSpot 'crew.levelUp'(S4 가이드 v2).
  final bool levelUpSpot;

  String get crewId => def.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('crewCard');
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (level, cards, status, up) = ref.watch(
      gameStateProvider.select((s) {
        final crew = s.crews[def.id];
        final up = crew == null ? 0 : mergeGain(crew, tables, maxLevel: crewMaxLevel(s, tables));
        return (crew?.level, crew?.cards, promoteStatus(s, tables, def.id), up);
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
              // 합치기로 레벨이 오르면 빛나는 초록 알약 '↑ +n' (피드백 #11·#16 — 합칠 수 있는 선원이 눈에 띄게).
              // 레벨 배지 바로 아래(그림 위) — 이름판·승급 버튼과 겹치지 않게.
              if (up > 0)
                Positioned(
                  left: -4,
                  top: 26,
                  child: Semantics(
                    label: l10n.uiCrewUpBadge,
                    child: TutorialSpot(
                      id: levelUpSpot ? 'crew.levelUp' : 'crew.up',
                      child: Container(
                        key: Key('crew.up.${def.id}'),
                        padding: const EdgeInsets.fromLTRB(4, 2, 7, 2),
                        decoration: BoxDecoration(
                          color: Skin.mint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Skin.outline, width: 2),
                          boxShadow: [
                            BoxShadow(color: Skin.mint.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 1),
                            ...Skin.shadowSmall,
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                            Text(l10n.uiCrewUpLevels(up), style: Skin.outlined(13)),
                          ],
                        ),
                      ),
                    ),
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
          // 특색 아이콘 4개 (조준·연사·범위·명중 — 선원 개성 v2).
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Center(
              child: FittedBox(child: CrewIdentityIcons(crewId: def.id, size: 13)),
            ),
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
