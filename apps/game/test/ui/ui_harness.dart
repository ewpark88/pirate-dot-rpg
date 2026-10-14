import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 샘플 상태 4개: new_player, stage37_midgame, boss_fight, all_crews_mythic.
/// flutter test는 apps/game에서 돌므로 저장소 루트의 fixtures/는 두 단계 위다.
GameState loadFixture(String name) {
  final file = File('../../fixtures/states/$name.json');
  return GameState.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

/// 세로 폰 화면(논리 400×800)에 앱을 그리고, 버튼이 보낸 명령을 모으는 로그를 돌려준다.
Future<CommandLog> pumpGame(
  WidgetTester tester,
  GameState state, {
  Locale? locale = const Locale('en'), // null이면 settings.lang → OS 언어
  int tab = 0,
  FixedClock? clock,
  bool keepTutorial = false,
}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 샘플은 모두 tutorialStep=1이다. 튜토리얼을 시험하는 테스트만 그대로 두고, 나머지는 끝난 상태로 그린다.
        initialGameStateProvider.overrideWithValue(keepTutorial ? state : state.copyWith(clearTutorial: true)),
        commandSinkProvider.overrideWithValue(log),
        // 시계는 샘플의 저장 시각에 고정 — 순풍 남은 시간 등이 매번 같게 (복귀 팝업도 안 뜬다).
        clockProvider.overrideWithValue(clock ?? FixedClock(state.savedAt)),
        // 전장은 렌더 레인 몫 — 같은 크기의 빈 상자로 바꿔 UI 테스트·골든이 전장 그림에 흔들리지 않게 한다.
        battleViewBuilderProvider.overrideWithValue((_) => const ColoredBox(color: Colors.blueGrey)),
      ],
      child: PirateDotApp(locale: locale),
    ),
  );
  await tester.pump();
  if (tab != 0) {
    await tester.tap(find.byType(NavigationDestination).at(tab));
    // 탭 표시 애니메이션을 끝까지.
    await tester.pump(); // 탭 상태 반영 → 애니메이션 시작
    await tester.pump(_tabAnimation);
  }
  return log;
}

/// 골든용 글꼴: Flutter SDK에 들어 있는 Roboto와 Material 아이콘을 읽는다.
/// 기본 글꼴(Ahem)은 글자를 네모로 그려 잘림을 볼 수 없다. Galmuri가 들어오면(art 레인) 그 글꼴로 바꾼다.
Future<void> loadGoldenFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

/// NavigationBar 선택 표시 애니메이션보다 넉넉히.
const _tabAnimation = Duration(seconds: 1);

/// 탭 순서 (탭 4개 고정).
const voyageTab = 0;
const shipTab = 1;
const crewTab = 2;
const summonTab = 3;
