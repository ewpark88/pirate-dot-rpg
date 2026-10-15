import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/battle_overlay.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/chest_layer.dart';
import 'package:pirate_dot/ui/hud/save_failure_banner.dart';
import 'package:pirate_dot/ui/hud/top_bar.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/pixel/pixel_tab_bar.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 세로 화면 하나: 위는 전장(항상 보임, HUD는 캔버스 + 누르는 것만 도트 오버레이), 아래 절반만 탭에 따라 바뀐다 (설계서 4.12).
/// 탭 4개 고정: 항해(전투)·배·선원·소환 (4.9 피로 금지 규칙). 버튼은 Command만 보낸다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// 전장(+ 선원 줄)이 차지하는 화면 높이 비율 (layout-v2-brief 2: 38~42%).
const _battleShare = 0.4;

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
              child: LayoutBuilder(
                builder: (context, screen) => Column(
                  children: [
                    const SaveFailureBanner(),
                    // 상단 바 (전장 밖): 골드·젬·순풍·퀘스트·설정.
                    const TopBar(),
                    // 전장 + 선원 줄: 폭 전체 × 화면의 40% (렌더가 남는 곳을 배경으로 채운다, layout-v2-brief 2·3).
                    SizedBox(
                      key: const Key('battle.area'),
                      height: screen.maxHeight * _battleShare,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ref.watch(battleViewBuilderProvider)?.call(context) ??
                              GameWidget(game: ref.watch(battleGameProvider)),
                          // 보물상자 탭(게임 오브젝트)과 선원 줄 오른쪽 끝 버튼만.
                          const ChestLayer(),
                          const BattleButtons(),
                        ],
                      ),
                    ),
                    const ChestAdStrip(),
                    const BossWeakness(),
                    // 다음 목표 도트 띠 (전장 바로 아래, 설계서 4.5).
                    const GoalBar(),
                    // 튜토리얼 중에만 자리를 차지한다 — 전장도 탭 패널도 가리지 않는다.
                    const TutorialBubble(),
                    Expanded(
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
            ),
            // 탭 4개 고정 (도트 탭 막대). 배·선원·소환은 튜토리얼이 가리킨다.
            bottomNavigationBar: PixelTabBar(
              children: [
                for (final (i, (asset, label, spot, badge)) in [
                  (UiSprites.tabMap, l10n.uiTabVoyage, null, false),
                  (UiSprites.tabShip, l10n.uiTabShip, 'tab.ship', ref.watch(shipBadgeProvider)),
                  (UiSprites.tabCrew, l10n.uiTabCrew, 'tab.crew', ref.watch(crewBadgeProvider)),
                  (UiSprites.tabSummon, l10n.uiTabSummon, 'tab.summon', ref.watch(summonBadgeProvider)),
                ].indexed)
                  PixelTabItem(
                    key: Key('tab.$i'),
                    label: label,
                    selected: _tab == i,
                    // 지금 보고 있는 탭에는 점을 띄우지 않는다 (이미 거기 있다).
                    badge: badge && _tab != i,
                    dotKey: Key('tab.dot.$i'),
                    onTap: () => _selectTab(i),
                    icon: spot == null
                        ? PixelSprite(asset, dots: 16)
                        : TutorialSpot(id: spot, child: PixelSprite(asset, dots: 16)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
