import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/crew/crew_preview.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 샘플 상태 4개: new_player, stage37_midgame, boss_fight, all_crews_mythic.
/// flutter test는 apps/game에서 돌므로 저장소 루트의 fixtures/는 두 단계 위다.
GameState loadFixture(String name) {
  final file = File('../../fixtures/states/$name.json');
  return GameState.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

/// 화물칸(골드 금고, S2 economy-cargo-capacity) 여유를 준 상태: 용량 ≥ 지금 골드 + [extra]가 될 때까지 화물칸 레벨을 올린다.
/// 샘플은 골드가 화물칸 용량보다 많아(가득) '가득' 알림·잘림이 끼므로, 그와 무관한 테스트가 쓴다.
GameState withCargoRoom(GameState s, {BigNum? extra}) {
  final t = GameTables.load();
  final need = s.wallet.gold + (extra ?? BigNum.zero);
  var lv = s.ship.level('cargo');
  final cargo = t.shipParts.byId('cargo');
  while (partEffect(cargo, lv) < need) {
    lv++;
  }
  return s.copyWith(ship: s.ship.copyWith(parts: {...s.ship.parts, 'cargo': lv}));
}

/// 세로 폰 화면(기본: 사용자 실기기 Galaxy S24 = 384×832dp, dpr 2.8125)에 앱을 그리고, 버튼이 보낸 명령을 모으는 로그를 돌려준다.
/// 사용자 실기기 Galaxy S24 (1080×2340px ÷ 2.8125).
const s24Size = Size(384, 832);
const s24Dpr = 2.8125;

Future<CommandLog> pumpGame(
  WidgetTester tester,
  GameState state, {
  Locale? locale = const Locale('en'), // null이면 settings.lang → OS 언어
  int tab = 0,
  FixedClock? clock,
  bool keepTutorial = false,
  bool guides = false,
  Size size = s24Size,
  double dpr = s24Dpr,
  List<Override> overrides = const [],
  bool openTab = true,
  bool fullSheet = false,
}) async {
  tester.view
    ..physicalSize = size * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  // 배 미리보기(렌더 ShipPreview) 그림을 진짜 시계에서 먼저 읽는다 — 앱이 가짜 시계 안에서 시작하면 그 미래가 끝나지 않는다.
  // 한 번 읽으면 같은 파일의 다음 테스트는 바로 지나간다.
  await tester.runAsync(() => _preloadShips().timeout(const Duration(seconds: 20), onTimeout: () {}));
  await tester.pumpWidget(
    ProviderScope(
      // 같은 테스트에서 다시 그려도 새 앱으로 시작한다(시트 열림 같은 화면 상태를 이어받지 않게).
      key: UniqueKey(),
      overrides: [
        // 샘플은 모두 tutorialStep=1이다. 튜토리얼을 시험하는 테스트만 그대로 두고, 나머지는 끝난 상태로 그린다.
        initialGameStateProvider.overrideWithValue(
          guides
              ? (keepTutorial ? state : state.copyWith(clearTutorial: true))
              : withGuidesSeen(keepTutorial ? state : state.copyWith(clearTutorial: true)),
        ),
        commandSinkProvider.overrideWithValue(log),
        // 처음 만나는 시스템 카드는 가이드를 시험하는 테스트(guides: true)에서만.
        guidesEnabledProvider.overrideWithValue(guides),
        // 시계는 샘플의 저장 시각에 고정 — 순풍 남은 시간 등이 매번 같게 (복귀 팝업도 안 뜬다).
        clockProvider.overrideWithValue(clock ?? FixedClock(state.savedAt)),
        // 전장은 렌더 레인 몫 — 같은 크기의 빈 상자로 바꿔 UI 테스트·골든이 전장 그림에 흔들리지 않게 한다.
        battleViewBuilderProvider.overrideWithValue((_) => const ColoredBox(color: Colors.blueGrey)),
        // 선원 공격 미리보기도 첫 장면만(끝없는 애니메이션이 pumpAndSettle을 막지 않게).
        crewPreviewPlayProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: PirateDotApp(locale: locale),
    ),
  );
  await tester.pump();
  // 도크 + 시트(2026-10-15): 탭 내용은 시트를 열어야 보인다 → 고른 탭 아이콘을 눌러 시트를 연다(항해 포함).
  if (openTab) {
    await tester.tap(find.byKey(Key('tab.$tab')));
    // 시트가 올라오는 시간 (첫 프레임에 애니메이션이 시작된다).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // 시트 열기 시작
    await tester.pump(_tabAnimation);
    // 시트를 끝까지(90%) 끌어올린다 — 긴 패널 전체를 보는 테스트용.
    if (fullSheet) {
      await tester.drag(find.byKey(const Key('sheet.handle')), Offset(0, -size.height * 0.45));
      await tester.pump();
      await tester.pump(_tabAnimation);
    }
  }
  return log;
}

/// 가이드 v2 '처음 만나는 시스템' 카드를 모두 본 것으로 둔 상태 — 하네스 없이 앱을 띄우는 테스트(실제 엔진 등)가 쓴다.
/// ([pumpGame]은 guidesEnabledProvider로 끈다. 샘플은 조건이 많이 맞아 모든 화면에 카드가 뜨기 때문.)
GameState withGuidesSeen(GameState s) {
  return s.copyWith(
    settings: Settings.fromJson({
      ...s.settings.toJson(),
      'battleView': s.settings.battleView,
      'hints': [...s.settings.hints, ...guideIds],
    }),
  );
}

/// [keep] 하나만 빼고 시스템 안내를 모두 본 것으로 (그 안내 하나만 시험).
GameState withGuidesSeenExcept(GameState s, String keep) => s.copyWith(
  settings: Settings.fromJson({
    ...s.settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': [...s.settings.hints, ...guideIds.where((id) => id != keep)],
  }),
);

Future<void>? _shipsLoaded;

Future<void> _preloadShips() => _shipsLoaded ??= () async {
  final tables = GameTables.load();
  await ShipPreview.preload(
    tables,
    skins: {
      for (final id in ['coral', 'storm', 'gold', 'phantom']) id: ?skinPalette(tables, id),
    },
  );
}();

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
  // 앱의 도트 폰트(한글 포함) — 이제 한국어 골든도 글자로 찍힌다.
  final assets = Directory('assets/fonts');
  final galmuri = FontLoader('Galmuri11');
  for (final f in ['Galmuri11.ttf', 'Galmuri11-Bold.ttf']) {
    galmuri.addFont(Future.value(ByteData.sublistView(File('${assets.path}/$f').readAsBytesSync())));
  }
  await galmuri.load();
  // 스킨 r1 글꼴 (Jua + 없는 기호 보충).
  for (final (family, file) in [('Jua', 'Jua-Regular.ttf'), ('GowunDodumSymbols', 'GowunDodumSymbols.ttf')]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(File('${assets.path}/$file').readAsBytesSync())));
    await loader.load();
  }
}

/// 탭 전환 뒤 화면이 자리 잡을 시간 (넉넉히).
const _tabAnimation = Duration(seconds: 1);

/// 골든을 찍기 전에 화면의 이미지(선원 초상 등)를 실제로 디코드한다. 안 하면 골든에 빈칸으로 찍힌다.
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image, skipOffstage: false).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

/// 탭 순서 (탭 4개 고정).
const voyageTab = 0;
const shipTab = 1;
const crewTab = 2;
const summonTab = 3;
