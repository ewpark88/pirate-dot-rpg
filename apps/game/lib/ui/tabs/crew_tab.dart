import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 격자 한 줄에 선원 수.
const _columns = 5;

/// 카드 가로:세로.
const _cardAspect = 0.45;

/// 미보유 선원 카드의 불투명도.
const _unownedOpacity = 0.35;

/// 승급 버튼을 보이는 상태 = 승급 문 앞(레벨은 됐고 카드·골드·증표만 남음).
const Set<PromoteStatus> _atGate = {PromoteStatus.ok, PromoteStatus.cards, PromoteStatus.gold, PromoteStatus.tokens};

/// 선원(원정대) 탭: 일괄 합치기, 도감 진척, 40명 격자 (설계서 4.3.1, 4.12).
// TODO(ui): 정렬, 보유 효과 합계, 선원 상세 창(발사체 미리보기), 증표 교환 — 다음 계획.
class CrewTab extends ConsumerWidget {
  const CrewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 보유·도감 수가 바뀔 때만 격자를 다시 짠다 (선원은 줄지 않으므로 수로 충분). 카드 내용은 CrewCard가 구독한다.
    final collected = ref.watch(gameStateProvider.select((s) => (s.collection.length, s.crews.length))).$1;
    final owned = ref.read(gameStateProvider).crews.keys.toSet();
    final crews = [...ref.watch(tablesProvider).crews.crews]..sort((a, b) => a.num.compareTo(b.num));
    final bonusOf = ref.watch(collectionBonusProvider);
    final bonus = ref.watch(
      gameStateProvider.select((s) {
        final b = bonusOf(s);
        return b == null ? null : (b.attackBonus, b.nextIn);
      }),
    );

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.uiCrewCollection(collected, crews.length)),
                  // 도감 보너스 (5명마다 공격력, 설계서 4.5) — 경제 함수가 오기 전엔 없음.
                  if (bonus case (final attack, final nextIn)) ...[
                    Text(
                      l10n.uiCollectionBonus(percentText(l10n, attack)),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (nextIn > 0) Text(l10n.uiCollectionNext(nextIn), style: Theme.of(context).textTheme.labelSmall),
                  ],
                ],
              ),
            ),
            TutorialSpot(
              id: 'crew.mergeAll',
              child: FilledButton(
                key: const Key('crew.mergeAll'),
                onPressed: () => ref.read(commandSinkProvider).send(const MergeAllCards()),
                child: Text(l10n.uiCrewMergeAll),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: _columns,
          childAspectRatio: _cardAspect,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in crews) CrewCard(def: c, owned: owned.contains(c.id)),
          ],
        ),
      ],
    );
  }
}

/// 선원 한 명: 이름·등급 테두리와 별·레벨·카드 수·출전 표시·승급 버튼.
class CrewCard extends ConsumerWidget {
  const CrewCard({required this.def, required this.owned, super.key});

  final CrewDef def;
  final bool owned;

  String get crewId => def.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (level, cards, deployed, status) = ref.watch(
      gameStateProvider.select((s) {
        final crew = s.crews[def.id];
        return (
          crew?.level,
          crew?.cards,
          s.battle?.fleet.any((f) => f.crewId == def.id) ?? false,
          promoteStatus(s, tables, def.id),
        );
      }),
    );
    final rarity = level == null
        ? tables.rarities.rarities.firstWhere((r) => r.id == def.baseRarity)
        : rarityOfLevel(tables.rarities, level);
    final small = Theme.of(context).textTheme.labelSmall;

    final card = Container(
      decoration: BoxDecoration(
        border: Border.all(color: rarityColor(rarity), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          Text(tableText(l10n, def.nameKey), maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
          _Stars(rarity: rarity),
          if (level != null && cards != null) ...[
            Text(l10n.uiLevel(level), style: small),
            Text(l10n.uiCrewCards(cards), style: small),
          ],
          if (deployed) Text(l10n.uiCrewDeployed, style: small?.copyWith(color: Colors.green.shade700)),
          const Spacer(),
          if (_atGate.contains(status)) _PromoteButton(crewId: def.id, ready: status == PromoteStatus.ok),
        ],
      ),
    );
    return owned ? card : Opacity(opacity: _unownedOpacity, child: card);
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rarity});

  final RarityDef rarity;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [for (var i = 0; i < rarity.stars; i++) Icon(Icons.star, size: 9, color: rarityColor(rarity))],
  );
}

class _PromoteButton extends ConsumerWidget {
  const _PromoteButton({required this.crewId, required this.ready});

  final String crewId;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = FilledButton(
      key: Key('crew.promote.$crewId'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size.fromHeight(24),
      ),
      onPressed: ready ? () => ref.read(commandSinkProvider).send(PromoteCrew(crewId)) : null,
      child: FittedBox(child: Text(AppLocalizations.of(context).uiCrewPromote)),
    );
    // 빨간 점은 지금 눌러서 이득일 때만 (설계서 4.9).
    return ready ? Badge(key: Key('crew.dot.$crewId'), smallSize: 8, child: button) : button;
  }
}
