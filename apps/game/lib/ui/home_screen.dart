import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/hud/hud_bar.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
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

/// 전장 위젯 주입점. null이면 Flame 전장(BattleGame). UI 테스트·골든은 빈 상자로 바꿔
/// 렌더 레인의 그림 변화와 분리한다 (전장 골든은 render 레인 몫).
final battleViewBuilderProvider = Provider<WidgetBuilder?>((_) => null);

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 엔진 라이브 입력(main이 EngineHost.ticks로 꽂는다). 없으면 데모 기록을 재생한다.
  /// 처음 그릴 때 만든다 — 주입된 전장 위젯을 쓰면 만들지 않는다.
  late final _game = BattleGame(feed: ref.read(battleFeedProvider), tables: ref.read(tablesProvider));
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
                  child: ref.watch(battleViewBuilderProvider)?.call(context) ?? GameWidget(game: _game),
                ),
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
    );
  }
}
