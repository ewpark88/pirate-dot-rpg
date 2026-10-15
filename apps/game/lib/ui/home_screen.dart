import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/hud/boss_challenge.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/chest_layer.dart';
import 'package:pirate_dot/ui/hud/hud_bar.dart';
import 'package:pirate_dot/ui/hud/tailwind_badge.dart';
import 'package:pirate_dot/ui/meta/daily_sheet.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 세로 화면 하나: 위는 HUD와 전장(항상 보임), 아래 절반만 탭에 따라 바뀐다 (설계서 4.12).
/// 탭 4개 고정: 항해(전투)·배·선원·소환 (4.9 피로 금지 규칙). 버튼은 Command만 보낸다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// 전장 : 탭 패널 높이 비율 (설계서 4.12의 38% : 37%).
const _battleFlex = 38;
const _panelFlex = 37;

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    // 이탈 분석(설계서 4.9): 마지막으로 본 화면·스테이지. 시작할 때, 탭을 바꿀 때, 스테이지가 바뀔 때 남긴다.
    ref.listenManual(gameStateProvider.select((s) => s.progress.stage), (_, _) => _reportLastSeen());
    _reportLastSeen();
  }

  void _reportLastSeen() => ref
      .read(analyticsPortProvider)
      .setLastSeen(screen: analyticsTabIds[_tab], stage: ref.read(gameStateProvider).progress.stage);

  void _selectTab(int i) {
    setState(() => _tab = i);
    _reportLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 팝업은 둘뿐: 복귀 오프라인 보상, 소환 결과 (설계서 4.12 — 승급 연출은 다음 계획).
    return OfflineRewardGate(
      child: SummonResultGate(
        child: RebirthDoneGate(
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const HudBar(),
                  const GoalBar(),
                  Expanded(
                    flex: _battleFlex,
                    child: Stack(
                      children: [
                        Center(
                          child: AspectRatio(
                            key: const Key('battle.area'),
                            aspectRatio: kLogicalWidth / kLogicalHeight,
                            // 전장(렌더) 위에 UI의 탭 영역(보물상자)을 같은 좌표로 겹친다.
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ref.watch(battleViewBuilderProvider)?.call(context) ??
                                    GameWidget(game: ref.watch(battleGameProvider)),
                                const ChestLayer(),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [BossChallenge(), BossWeakness()],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [TailwindBadge(), TailwindAdButton(), SizedBox(height: 4), DailyIcon()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 튜토리얼 중에만 자리를 차지한다 — 전장도 탭 패널도 가리지 않는다.
                  const TutorialBubble(),
                  Expanded(
                    flex: _panelFlex,
                    child: IndexedStack(
                      index: _tab,
                      children: const [
                        VoyageTab(),
                        ShipTab(),
                        CrewTab(),
                        SummonTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              destinations: [
                NavigationDestination(
                  icon: const _TabIcon(UiSprites.tabMap),
                  selectedIcon: const _TabIcon(UiSprites.tabMap, selected: true),
                  label: l10n.uiTabVoyage,
                ),
                NavigationDestination(
                  icon: const TutorialSpot(id: 'tab.ship', child: _TabIcon(UiSprites.tabShip)),
                  selectedIcon: const TutorialSpot(id: 'tab.ship', child: _TabIcon(UiSprites.tabShip, selected: true)),
                  label: l10n.uiTabShip,
                ),
                NavigationDestination(
                  icon: const TutorialSpot(id: 'tab.crew', child: _TabIcon(UiSprites.tabCrew)),
                  selectedIcon: const TutorialSpot(id: 'tab.crew', child: _TabIcon(UiSprites.tabCrew, selected: true)),
                  label: l10n.uiTabCrew,
                ),
                NavigationDestination(
                  icon: const TutorialSpot(id: 'tab.summon', child: _TabIcon(UiSprites.tabSummon)),
                  selectedIcon: const TutorialSpot(
                    id: 'tab.summon',
                    child: _TabIcon(UiSprites.tabSummon, selected: true),
                  ),
                  label: l10n.uiTabSummon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 탭 아이콘 (아트 레인 16px 그림). 그림에 색이 있어 고른 탭은 바탕 표시(인디케이터)로, 나머지는 살짝 어둡게.
class _TabIcon extends StatelessWidget {
  const _TabIcon(this.asset, {this.selected = false});

  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final sprite = PixelSprite(asset, dots: 16);
    return selected ? sprite : Opacity(opacity: 0.6, child: sprite);
  }
}
