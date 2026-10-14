import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/hud/boss_challenge.dart';
import 'package:pirate_dot/ui/hud/chest_layer.dart';
import 'package:pirate_dot/ui/hud/hud_bar.dart';
import 'package:pirate_dot/ui/hud/tailwind_badge.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';
import 'package:pirate_dot/ui/tabs/ship_tab.dart';
import 'package:pirate_dot/ui/tabs/summon_tab.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OfflineRewardGate(
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
                    const Positioned(top: 8, right: 8, child: BossChallenge()),
                    const Positioned(top: 8, left: 8, child: TailwindBadge()),
                  ],
                ),
              ),
              Expanded(
                flex: _panelFlex,
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    SizedBox.shrink(), // 항해 탭: 다음 계획 (해역 지도·환생)
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
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.sailing), label: l10n.uiTabVoyage),
            NavigationDestination(icon: const Icon(Icons.directions_boat), label: l10n.uiTabShip),
            NavigationDestination(icon: const Icon(Icons.groups), label: l10n.uiTabCrew),
            NavigationDestination(icon: const Icon(Icons.auto_awesome), label: l10n.uiTabSummon),
          ],
        ),
      ),
    );
  }
}
