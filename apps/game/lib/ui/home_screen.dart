import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/hud/hud_bar.dart';

/// 세로 화면 하나: 위는 HUD와 전장(항상 보임), 아래 절반만 탭에 따라 바뀐다 (설계서 4.12).
/// 탭 4개 고정: 항해(전투)·배·선원·소환 (4.9 피로 금지 규칙). 버튼은 Command만 보낸다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 전장 : 탭 패널 높이 비율 (설계서 4.12의 38% : 37%).
const _battleFlex = 38;
const _panelFlex = 37;

class _HomeScreenState extends State<HomeScreen> {
  final _game = BattleGame();
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HudBar(),
            Expanded(
              flex: _battleFlex,
              child: Center(
                child: AspectRatio(
                  aspectRatio: kLogicalWidth / kLogicalHeight,
                  child: GameWidget(game: _game),
                ),
              ),
            ),
            Expanded(
              flex: _panelFlex,
              child: IndexedStack(
                index: _tab,
                children: const [
                  SizedBox.shrink(), // 항해 탭: 다음 계획 (해역 지도·환생)
                  SizedBox.shrink(),
                  SizedBox.shrink(),
                  SizedBox.shrink(),
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
    );
  }
}
