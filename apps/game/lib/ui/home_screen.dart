import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';

/// 탭 4개 고정: 항해(전투)·배·선원·소환 (docs/GAME_DESIGN.md 4.9 피로 금지 규칙).
/// UI 레인(S4)이 각 탭을 채운다. 버튼은 Command만 보낸다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _game = BattleGame();
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.uiAppTitle)),
      body: AspectRatio(
        aspectRatio: kLogicalWidth / kLogicalHeight,
        child: GameWidget(game: _game),
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
