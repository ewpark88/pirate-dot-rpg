import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
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
  Locale locale = const Locale('en'),
  int tab = 0,
}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(state),
        commandSinkProvider.overrideWithValue(log),
      ],
      child: PirateDotApp(locale: locale),
    ),
  );
  await tester.pump();
  if (tab != 0) {
    await tester.tap(find.byType(NavigationDestination).at(tab));
    await tester.pump();
  }
  return log;
}

/// 탭 순서 (탭 4개 고정).
const voyageTab = 0;
const shipTab = 1;
const crewTab = 2;
const summonTab = 3;
