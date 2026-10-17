import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_filter.dart';
import 'package:pirate_dot/ui/crew/crew_filter_bar.dart';
import 'package:pirate_dot/ui/crew/crew_header.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tabs/crew_card.dart';

export 'package:pirate_dot/ui/tabs/crew_card.dart' show CrewCard;

/// 카드 한 장의 목표 폭(dp) — 폭이 넓으면(태블릿) 열을 늘린다: 폰 4열 … 최대 8열.
const _cardTargetWidth = 96.0;
const _minColumns = 4;
const _maxColumns = 8;

/// 카드 사이 간격.
const _spacing = 4.0;

/// 선원(원정대) 탭: 일괄 합치기, 도감 진척, 40명 격자 (설계서 4.3.1, 4.12).
// TODO(ui): 정렬, 보유 효과 합계, 선원 상세 창(발사체 미리보기), 증표 교환 — 다음 계획.
class CrewTab extends ConsumerWidget {
  const CrewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('crewTab');
    final l10n = AppLocalizations.of(context);
    // 보유·도감 수가 바뀔 때만 격자를 다시 짠다 (선원은 줄지 않으므로 수로 충분). 카드 내용은 CrewCard가 구독한다.
    ref.watch(gameStateProvider.select((s) => (s.collection.length, s.crews.length)));
    final owned = ref.read(gameStateProvider).crews.keys.toSet();
    final tables = ref.watch(tablesProvider);
    // 정렬·필터 (사용자 지시 2026-10-16). 선원 레벨·경험치가 바뀔 때만 다시 고른다(공격력순·합치기 가능이 따라 바뀜).
    final query = ref.watch(crewQueryProvider);
    ref.watch(
      gameStateProvider.select(
        (s) => [for (final e in s.crews.entries) '${e.key}${e.value.level}.${e.value.exp}'].join(),
      ),
    );
    final crews = queryCrews(ref.read(gameStateProvider), tables, query);
    // 합칠 수 있는 선원 수(일괄 합치기 글)와 목록에서 첫 번째(가이드 'crew.levelUp'). 위 watch가 레벨·경험치 변화에 다시 짓는다.
    final ups = levelUpIds(ref.read(gameStateProvider), tables);
    final mergeCount = ups.length;
    final firstUp = crews.where((c) => ups.contains(c.id)).firstOrNull?.id;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // 머리 한 줄: 도감 · 보상 · 자동 편성 · 일괄 합치기 (열자마자 카드 첫 줄이 보이게, S1 실기기 ③).
        CrewHeader(mergeCount: mergeCount),
        const SizedBox(height: 6),
        // 합치기 가능 n명 · 정렬 · 보유 · 특성 필터.
        const CrewQueryBar(),
        const SizedBox(height: 8),
        if (crews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.uiFilterEmpty,
                key: const Key('crew.filter.empty'),
                style: Skin.text(15, color: Skin.sub),
              ),
            ),
          ),
        // 기준 gif 아래 선원 바처럼 큰 정사각 초상 카드. 줄마다 높이가 달라도 되게(승급 버튼이 있는 줄만 길어짐) 격자 대신 줄.
        // 테스트·도감이 40장을 모두 찾을 수 있게 한 덩어리로 짓는다(ListView는 화면 밖 자식을 안 지음).
        LayoutBuilder(
          builder: (context, box) {
            final columns = (box.maxWidth / _cardTargetWidth).floor().clamp(_minColumns, _maxColumns);
            return Column(
              children: [
                for (var i = 0; i < crews.length; i += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _spacing),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var j = i; j < i + columns; j++) ...[
                          if (j > i) const SizedBox(width: _spacing),
                          Expanded(
                            child: j < crews.length
                                ? CrewCard(
                                    def: crews[j],
                                    owned: owned.contains(crews[j].id),
                                    levelUpSpot: crews[j].id == firstUp,
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
