import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tabs/crew_card.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

export 'package:pirate_dot/ui/tabs/crew_card.dart' show CrewCard;

/// 격자 한 줄에 선원 수.
const _columns = 4;

/// 카드 사이 간격.
const _spacing = 4.0;

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
            // 도감: 한 줄(수 · 공격력 보너스) + 도트 막대(전체 진척)와 다음 보너스까지.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      Text(l10n.uiCrewCollection(collected, crews.length)),
                      // 도감 보너스 (5명마다 공격력, 설계서 4.5) — 경제 함수가 오기 전엔 없음.
                      if (bonus case (final attack, _))
                        Text(
                          l10n.uiCollectionBonus(percentText(l10n, attack)),
                          style: const TextStyle(color: PixelPalette.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: PixelBar(
                          key: const Key('crew.collectionBar'),
                          value: collected / crews.length,
                          fill: PixelPalette.accent,
                        ),
                      ),
                      if (bonus case (_, final nextIn) when nextIn > 0) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.uiCollectionNext(nextIn),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: PixelPalette.textDim),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TutorialSpot(
              id: 'crew.mergeAll',
              child: PixelDot(
                dotKey: const Key('crew.mergeAll.dot'),
                show: ref.watch(mergeBadgeProvider),
                child: PixelButton(
                  key: const Key('crew.mergeAll'),
                  primary: true,
                  onPressed: () => ref.read(commandSinkProvider).send(const MergeAllCards()),
                  child: Text(l10n.uiCrewMergeAll),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 수동 편성이 기본, 한 번에 채우기 (사용자 결정).
        Align(
          alignment: Alignment.centerRight,
          child: PixelButton(
            key: const Key('fleet.auto'),
            onPressed: () => ref.read(fleetCommandsProvider).auto(),
            child: Text(l10n.uiFleetAuto),
          ),
        ),
        const SizedBox(height: 6),
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
