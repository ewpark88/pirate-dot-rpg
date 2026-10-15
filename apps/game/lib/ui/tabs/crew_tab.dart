import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 격자 한 줄에 선원 수.
const _columns = 5;

/// 카드 사이 간격.
const _spacing = 4.0;

/// 초상 그림 한 변의 도트 수 (도트 팩 32×32).
const _portraitDots = 32;

/// 미보유 선원 실루엣 색 (도트 윤곽색).
const Color _silhouette = PixelPalette.outline;

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
        if (b == null) return null;
        // 경제는 다음 보너스가 붙는 보유 수(nextAt)를 준다 → 남은 명 수. 다 모았으면(null) 0.
        final next = b.nextAt;
        return (b.attackBonus, next == null ? 0 : next - b.owned);
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
              child: PixelButton(
                key: const Key('crew.mergeAll'),
                primary: true,
                onPressed: () => ref.read(commandSinkProvider).send(const MergeAllCards()),
                child: Text(l10n.uiCrewMergeAll),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 기준 gif 아래 선원 바처럼 큰 정사각 초상 카드. 줄마다 높이가 달라도 되게(승급 버튼이 있는 줄만 길어짐) 격자 대신 줄.
        // 테스트·도감이 40장을 모두 찾을 수 있게 한 덩어리로 짓는다(ListView는 화면 밖 자식을 안 지음).
        Column(
          children: [
            for (var i = 0; i < crews.length; i += _columns)
              Padding(
                padding: const EdgeInsets.only(bottom: _spacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = i; j < i + _columns; j++) ...[
                      if (j > i) const SizedBox(width: _spacing),
                      Expanded(
                        child: j < crews.length
                            ? CrewCard(def: crews[j], owned: owned.contains(crews[j].id))
                            : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
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
    final color = rarityColor(rarity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PortraitBox(def: def, color: color, owned: owned, rarity: rarity, deployed: deployed),
        // 이름은 두 줄까지 (영어 "Octo the Brawler"가 말줄임 없이 들어가게).
        Text(
          tableText(l10n, def.nameKey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: (owned ? small : small?.copyWith(color: PixelPalette.textDim)),
        ),
        // 레벨 · 카드 수를 한 줄에 작게.
        if (level != null && cards != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.uiLevel(level)),
                TextSpan(
                  text: ' ×$cards',
                  style: const TextStyle(color: PixelPalette.textDim),
                ),
              ],
            ),
            key: Key('crew.info.${def.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: small,
          ),
        if (_atGate.contains(status)) _PromoteButton(crewId: def.id, ready: status == PromoteStatus.ok),
      ],
    );
  }
}

/// 등급색 두꺼운 도트 테두리 안의 정사각 초상 (등급색을 옅게 깐 바탕, 아래 별, 출전이면 위 띠).
/// 미보유는 어두운 단색 실루엣 — 테두리·별은 그대로 보여 무엇을 모을지 알 수 있다.
class _PortraitBox extends StatelessWidget {
  const _PortraitBox({
    required this.def,
    required this.color,
    required this.owned,
    required this.rarity,
    required this.deployed,
  });

  final CrewDef def;
  final Color color;
  final bool owned;
  final RarityDef rarity;
  final bool deployed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return AspectRatio(
      aspectRatio: 1,
      child: PixelFrame(
        border: color,
        fill: Color.lerp(PixelPalette.navy, color, owned ? 0.35 : 0.18)!,
        highlight: null,
        borderDots: 2,
        child: LayoutBuilder(
          builder: (context, box) {
            // 초상은 실제 픽셀의 정수배로만 키운다(최근접 확대가 고르게).
            final scale = math.max(1, (box.maxWidth * dpr / _portraitDots).floor());
            final portrait = CrewPortrait(crew: def, size: scale * _portraitDots / dpr);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (owned)
                  portrait
                else
                  ColorFiltered(colorFilter: const ColorFilter.mode(_silhouette, BlendMode.srcIn), child: portrait),
                Positioned(right: 0, bottom: 0, child: _Stars(rarity: rarity)),
                if (deployed)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: ColoredBox(
                      color: PixelPalette.outline,
                      child: Text(
                        l10n.uiCrewDeployed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: PixelPalette.accent),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 등급 별: 별 그림 하나 + 개수 (16px 별 5개는 초상 폭을 넘는다). 숫자는 등급 색.
class _Stars extends StatelessWidget {
  const _Stars({required this.rarity});

  final RarityDef rarity;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PixelPalette.outline,
    child: Row(
      key: const Key('crew.stars'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const PixelSprite(UiSprites.star, dots: 16, scale: 1),
        Padding(
          padding: const EdgeInsets.only(left: 1, right: 2),
          child: Text(
            rarity.stars.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: rarityColor(rarity), height: 1),
          ),
        ),
      ],
    ),
  );
}

class _PromoteButton extends ConsumerWidget {
  const _PromoteButton({required this.crewId, required this.ready});

  final String crewId;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = PixelButton(
      key: Key('crew.promote.$crewId'),
      primary: true,
      onPressed: ready ? () => ref.read(commandSinkProvider).send(PromoteCrew(crewId)) : null,
      child: FittedBox(child: Text(AppLocalizations.of(context).uiCrewPromote)),
    );
    // 빨간 점은 지금 눌러서 이득일 때만 (설계서 4.9).
    return ready
        ? Badge(key: Key('crew.dot.$crewId'), smallSize: 8, backgroundColor: PixelPalette.danger, child: button)
        : button;
  }
}
