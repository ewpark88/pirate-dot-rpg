import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/viewport/integer_scale.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import '../ui/ui_harness.dart' show crewTab, loadGoldenFonts, precacheImages, shipTab, summonTab, voyageTab;

/// 스토어 스크린샷 8장 굽기 (docs/store/listing.ko.md 목록 순서). 골든이 아니다 — 비교하지 않고 PNG를 쓴다.
///
///     cd apps/game
///     STORE_SHOTS=ko flutter test test/store/store_shots_test.dart   → build/store/screens/ko/01_….png
///     STORE_DEVICE=tablet10 STORE_SHOTS=ko flutter test …                → build/store/screens/tablet10/ko/ (tablet7도 있음)
///     python -I -B docs/store/flatten_png.py                              → Play 규격 24비트 PNG(알파 없음)로
///     STORE_SHOTS=en flutter test test/store/store_shots_test.dart
///
/// 평소(check)에는 건너뛴다. 메모리를 아끼려고 한 번에 한 언어만 굽는다.
/// 전장은 빈 상자가 아니라 **실제 엔진**을 샘플 상태에서 돌린 기록을 렌더 레인의 BattleScene·ScenePainter로 그린다
/// (앱과 같은 정수배 확대). 411×731 논리 × 2.625 = 1080×1920 (Play 휴대전화 9:16, 흔한 Pixel 크기).
/// 전장은 물리 픽셀 기준 정수 3배라 도트가 선명하다. 운영자 패널은 없다(OPERATOR 꺼짐 — 샘플의 운영자 명령은 엔진 기록에만 쓴다).
void main() {
  final lang = Platform.environment['STORE_SHOTS'];
  // 기기: phone(기본) · tablet7 · tablet10 — Play 태블릿 스크린샷은 세로 9:16, 1080~7680px.
  final device = _devices[Platform.environment['STORE_DEVICE'] ?? 'phone']!;
  final enabled = lang == 'ko' || lang == 'en';
  final tables = GameTables.load();
  SpriteBank? bank;
  late final _Run mid;
  late final _Run ult;
  late final _Run boss;
  // 탭 화면: 후반 샘플(전 선원 신화·큰 배)을 해역마다 옮겨 하늘·바다 색이 장마다 다르게. 필요할 때 만든다(메모리).
  final lateRuns = <int, _Run>{};
  _Moment late(int stage) => lateRuns
      .putIfAbsent(
        stage,
        () => _Run(
          tables,
          _fixture('all_crews_mythic', skin: 'phantom'),
          ticks: 320,
          commands: {
            0: [OpJumpStage(stage)],
          },
        ),
      )
      .at(300);

  setUpAll(() async {
    if (!enabled) return;
    await loadGoldenFonts();
    // 해역 다양화(2026-10-15, 산호~유령 6해역 그림 다 있음). 운영자 명령은 엔진 기록에만 쓴다 — listing: "샘플 상태로 화면을 맞춘다".
    // 중반 함대(스테이지 37 샘플)를 산호해 44·무리 30으로: 실제 37 무리(7마리)는 화면 오른쪽 끝에서 다 죽어 장면이 비어 보인다. 무적.
    mid = _Run(
      tables,
      _fixture('stage37_midgame', skin: 'coral'),
      ticks: 2600,
      commands: {
        0: [const OpSetInvincible(on: true), const OpJumpStage(44), const OpSetWave(count: 40)],
      },
    );
    // 궁극기: 같은 산호해 44 장면을 함성 게이지 0.95에서 시작 → 무리가 화면에 찬 채로 궁극기.
    // (폭풍해 51은 중반 함대가 거의 못 잡아 게이지가 안 차 궁극기가 안 난다 — 2026-10-15 확인)
    ult = _Run(
      tables,
      _fixture('stage37_midgame', rage: 0.95, skin: 'storm'),
      ticks: 600,
      commands: {
        0: [const OpSetInvincible(on: true), const OpJumpStage(44), const OpSetWave(count: 40)],
      },
    );
    // 해역 보스: 화산해 200(용암 고래). 신화 함대는 보스를 몇 초 만에 잡으니 중반 함대로 오래 싸운다.
    // 폭풍해 번개 가오리는 관통 선원이 없으면 보호막(청록 상자)이 내내 켜져 있어 고르지 않았다.
    boss = _Run(
      tables,
      _fixture('stage37_midgame', skin: 'gold'),
      ticks: 900,
      commands: {
        0: [const OpJumpStage(200), const OpSetInvincible(on: true)],
        20: [const OpSpawnBoss()],
      },
    );
  });

  Future<void> shot(
    WidgetTester tester,
    String file,
    _Moment m, {
    int tab = voyageTab,
    List<Override> extra = const [],
    Duration? away,
    Future<void> Function()? act,
  }) async {
    bank ??= (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final painter = ScenePainter(m.play(tables))..sprites = bank;
    await _pump(
      tester,
      m.state,
      locale: Locale(lang!),
      tab: tab,
      painter: painter,
      device: device,
      away: away,
      extra: extra,
    );
    if (act != null) await act();
    await precacheImages(tester);
    await _save(tester, '../../build/store/screens/${device.dir}$lang/$file.png', device);
  }

  group('스토어 스크린샷 ($lang)', skip: !enabled, () {
    testWidgets('01 무리 동시 처치', (tester) async {
      // 동시 처치 가운데 화면에 적이 가장 많은 순간.
      await shot(tester, '01_multikill', mid.best((e) => e is MultiKill && e.count >= 3, ticks: 3));
    });

    testWidgets('02 궁극기', (tester) async {
      await shot(tester, '02_ultimate', ult.best((e) => e is UltimateCast, ticks: 12));
    });

    testWidgets('03 배 탭', (tester) async {
      await shot(tester, '03_ship', late(60), tab: shipTab);
    });

    testWidgets('04 10연 소환 결과', (tester) async {
      const ten = [
        SummonResult(crewId: 'manta', rarity: 'legend', isNew: true),
        SummonResult(crewId: 'starry', rarity: 'common'),
        SummonResult(crewId: 'uni', rarity: 'hero'),
        SummonResult(crewId: 'pingu', rarity: 'rare'),
        SummonResult(crewId: 'pang', rarity: 'common'),
        SummonResult(crewId: 'crabs', rarity: 'rare'),
        SummonResult(crewId: 'octo', rarity: 'common'),
        SummonResult(crewId: 'lamp', rarity: 'hero'),
        SummonResult(crewId: 'pingu', rarity: 'common'),
        SummonResult(crewId: 'bones', rarity: 'common'),
      ];
      final m = late(120);
      await shot(
        tester,
        '04_summon',
        m.withState(m.state.copyWith(lastSummon: ten)),
        tab: summonTab,
        act: () async {
          await tester.pumpAndSettle();
          final reveal = find.byKey(const Key('summon.revealAll'));
          if (reveal.evaluate().isNotEmpty) {
            await tester.tap(reveal);
            await tester.pumpAndSettle();
          }
          // 전설 이상이면 컷인이 하나씩 뜬다 — 눌러 닫아 결과 격자가 보이게.
          for (var i = 0; i < 10 && find.byKey(const Key('summon.cutin')).evaluate().isNotEmpty; i++) {
            await tester.tap(find.byKey(const Key('summon.cutin')));
            await tester.pumpAndSettle();
          }
        },
      );
    });

    testWidgets('05 선원 탭', (tester) async {
      await shot(tester, '05_crew', late(270), tab: crewTab);
    });

    testWidgets('06 해역 보스', (tester) async {
      // 컷인이 끝난 뒤(5초) 보스와 싸우는 장면.
      // 보스가 화면 가운데쯤이고, 최근 6틱 안에 공격이 없어 폭발이 보스를 덮지 않은 순간.
      await shot(
        tester,
        '06_boss',
        boss.firstClear(
          after: (e) => e is BossSpawned,
          skip: 80,
          frame: (f) => f.enemies.any((e) => e.boss && !e.shielded && _inCamera(tables, e.x, e.y, inner: 0.85)),
          quiet: (e) => e is AttackFired || e is AoeDamageSum,
          quietTicks: 6,
        ),
      );
    });

    testWidgets('07 복귀 보상', (tester) async {
      await shot(
        tester,
        '07_offline',
        late(220),
        away: const Duration(hours: 7, minutes: 25),
        act: () async {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      );
    });

    testWidgets('08 환생(보물지도)', (tester) async {
      // 후반 상태라 환생이 열려 있다 — 항해 탭의 보물지도 카드가 보이게 아래로 굴린다.
      await shot(
        tester,
        '08_rebirth',
        late(75),
        // 후반 상태라 환생이 열려 있다 — 보물지도 카드의 버튼으로 확인 창(얻을 조각·보너스)을 연다.
        act: () async {
          // 도크·시트 화면(탑다운): 항해 카드는 시트 안 — 도크의 항해 아이콘을 눌러 시트를 연다.
          await tester.tap(find.byKey(const Key('tab.$voyageTab')));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final open = find.byKey(const Key('rebirth.open'));
          // 항해 탭 목록은 보이는 부분만 만든다 — 카드가 생길 때까지 굴린다(지루함 해소 카드가 위에 더 생김).
          await tester.scrollUntilVisible(open, 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(open);
          await tester.pumpAndSettle();
        },
      );
    });
  });
}

/// 스크린샷 기기. 물리 픽셀은 모두 9:16(Play 규격). 전장은 물리 픽셀 정수배라 도트가 선명하다.
class _Device {
  const _Device(this.width, this.height, this.dpr, this.dir);

  final double width;
  final double height;
  final double dpr;

  /// `build/store/screens/` 아래 하위 폴더(휴대전화는 예전 경로 그대로).
  final String dir;

  Size get logical => Size(width / dpr, height / dpr);
}

const _devices = {
  'phone': _Device(1080, 1920, 2.625, ''), // 411×731dp, 흔한 Pixel
  'tablet7': _Device(1440, 2560, 2.4, 'tablet7/'), // 600×1067dp
  'tablet10': _Device(1800, 3200, 2.25, 'tablet10/'), // 800×1422dp
};
const _sea = Color(0xFF1B4F72); // BattleGame.backgroundColor와 같게
final GlobalKey _shotKey = GlobalKey();

/// [rage]: 함성 게이지를 미리 채워 둔다(궁극기 장면용 — 실제 스테이지에선 게이지가 차는 데 몇 분 걸린다).
GameState _fixture(String name, {double? rage, String? skin}) {
  final json = jsonDecode(File('../../fixtures/states/$name.json').readAsStringSync()) as Map<String, dynamic>;
  if (rage != null) (json['progress'] as Map<String, dynamic>)['rage'] = rage;
  final s = GameState.fromJson(json).copyWith(clearTutorial: true);
  if (skin == null) return s;
  // 환생 스킨(산호·폭풍·황금·유령)을 입혀 장마다 배 색이 다르게 — 스킨은 환생 보상이라 '보물지도' 장면과 맞다.
  final ship = s.ship;
  return s.copyWith(
    ship: ShipState(
      parts: ship.parts,
      honorParts: ship.honorParts,
      honorTier: ship.honorTier,
      skin: skin,
      skinsOwned: {...ship.skinsOwned, skin},
      skinChosen: true,
    ),
  );
}

/// 탑다운 카메라(배 중심 가운데, waves.top viewWidth × viewHeight) 안쪽 [inner] 비율 안인가.
bool _inCamera(GameTables t, double x, double y, {double inner = 1}) {
  final top = t.waves.raw.obj('top');
  return (x - top.number('shipX')).abs() <= top.number('viewWidth') / 2 * inner &&
      (y - top.number('shipY')).abs() <= top.number('viewHeight') / 2 * inner;
}

/// 샘플 상태에서 실제 엔진을 [ticks]만큼 돌린 기록.
class _Run {
  _Run(this.tables, GameState start, {required int ticks, Map<int, List<Command>> commands = const {}}) {
    final engine = CoreEngine(tables: tables, clock: ManualClock(start.savedAt), initial: start);
    for (var t = 0; t < ticks; t++) {
      commands[t]?.forEach(engine.enqueue);
      engine.tick();
      this.ticks.add(RecordedTick(engine.state.battle ?? BattleView.empty, engine.drainEvents()));
      states.add(engine.state);
    }
  }

  final GameTables tables;
  final ticks = <RecordedTick>[];
  final states = <GameState>[];

  /// [match] 이벤트가 처음 난 틱에서 [ticks]만큼 지난 순간. 앞 3초를 함께 재생해 화면이 자연스럽게 차 있게 한다.
  _Moment after(bool Function(GameEvent e) match, {required int ticks}) {
    final at = this.ticks.indexWhere((t) => t.events.any(match));
    if (at < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    return _at(at + ticks);
  }

  /// [match]가 난 틱들 가운데 [ticks] 뒤 화면 안(x < 320) 적이 가장 많은 순간 (앞쪽 [before] 틱 안에서).
  _Moment best(bool Function(GameEvent e) match, {required int ticks, int? before}) {
    var bestAt = -1;
    var most = -1;
    final end = (before ?? this.ticks.length) - ticks;
    for (var i = 0; i < end && i + ticks < this.ticks.length; i++) {
      if (!this.ticks[i].events.any(match)) continue;
      // 처치가 카메라 안쪽(가장자리 20% 밖 제외)에서 났을 때만(가장자리에서 나면 연출이 잘린다) — 탑다운 카메라 기준.
      final kills = this.ticks[i].events.whereType<Kill>().toList();
      if (kills.isNotEmpty && !kills.every((k) => _inCamera(tables, k.x, k.y, inner: 0.8))) continue;
      final n = this.ticks[i + ticks].frame.enemies.where((e) => _inCamera(tables, e.x, e.y)).length;
      if (n > most) (bestAt, most) = (i, n);
    }
    if (bestAt < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    return _at(bestAt + ticks);
  }

  /// [after] 이벤트 뒤 [skip]틱부터, 화면이 [frame]을 만족하고 앞 [quietTicks] 안에 [quiet] 이벤트가 없는 첫 틱.
  _Moment firstClear({
    required bool Function(GameEvent e) after,
    required int skip,
    required bool Function(BattleView f) frame,
    required bool Function(GameEvent e) quiet,
    required int quietTicks,
  }) {
    final start = ticks.indexWhere((t) => t.events.any(after));
    if (start < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    for (var i = start + skip; i < ticks.length; i++) {
      final calm = ticks.sublist(i - quietTicks, i + 1).every((t) => !t.events.any(quiet));
      if (calm && frame(ticks[i].frame)) return _at(i);
    }
    throw StateError('조건에 맞는 순간이 없다 — 틱 수를 늘린다');
  }

  /// 정해진 틱 (탭 화면 배경용).
  _Moment at(int tick) => _at(tick);

  _Moment _at(int tick) {
    final target = tick.clamp(0, ticks.length - 1);
    final from = (target - 60).clamp(0, target);
    return _Moment(ticks.sublist(from, target + 1), states[target]);
  }
}

class _Moment {
  const _Moment(this.ticks, this.state);

  final List<RecordedTick> ticks;
  final GameState state;

  _Moment withState(GameState s) => _Moment(ticks, s);

  /// 마지막 틱에 닿을 때까지 60fps로 재생한 장면. 배속(BattleView.speed)만큼 빨리 지나가므로 시간이 아니라 위치로 멈춘다
  /// — 끝을 지나 더 돌리면 이펙트·숫자가 다 사라진 빈 장면이 찍힌다.
  BattleScene play(GameTables tables) {
    // 정지 화면이라 흔들림·화면 번쩍임은 끈다(설정에 있는 선택지) — 번쩍임이 찍히면 화면 전체가 하얗게 씻긴다.
    final scene = BattleScene(tables, ticks, loop: false, settings: const JuiceSettings(shake: false, flash: false));
    final end = ticks.length - 1;
    for (var frames = 0; scene.player.position < end && frames < _maxFrames; frames++) {
      scene.update(kFrameMs);
    }
    return scene;
  }

  static const int _maxFrames = 60 * 60;
}

/// 전장 한 장면을 앱과 같은 정수배로 (BattleGame.onGameResize와 같은 계산).
class _ScenePaint extends CustomPainter {
  _ScenePaint(this.painter, this.dpr);

  final ScenePainter painter;
  final double dpr;

  @override
  void paint(ui.Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _sea);
    if (painter.scene.isTop) {
      // 탑다운: 앱(BattleGame)과 같이 캔버스를 상자 dp 그대로 두고 탑다운 카메라로 그린다.
      painter.scene.layout = battleFrameFor(size, dpr);
      painter.paintTop(canvas, topFrameFor(size, dpr));
      return;
    }
    final s = integerScale(size.width, size.height, dpr: dpr);
    canvas
      ..save()
      ..translate(s.offsetX, s.offsetY)
      ..scale(s.scale);
    painter.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // 시트가 열려 상자가 줄면 다시 그린다(앱과 같은 크기)
}

Future<void> _pump(
  WidgetTester tester,
  GameState state, {
  required Locale locale,
  required int tab,
  required ScenePainter painter,
  required _Device device,
  Duration? away,
  List<Override> extra = const [],
}) async {
  tester.view
    ..physicalSize = device.logical * device.dpr
    ..devicePixelRatio = device.dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(state.copyWith(clearTutorial: true)),
        commandSinkProvider.overrideWithValue(_NoCommands()),
        // 시계: 저장 시각(복귀 팝업 없음) 또는 [away] 뒤(복귀 팝업).
        clockProvider.overrideWithValue(FixedClock(state.savedAt.add(away ?? Duration.zero))),
        battleViewBuilderProvider.overrideWithValue(
          (context) => CustomPaint(size: Size.infinite, painter: _ScenePaint(painter, device.dpr)),
        ),
        ...extra,
      ],
      child: RepaintBoundary(
        key: _shotKey,
        child: PirateDotApp(locale: locale),
      ),
    ),
  );
  await tester.pump();
  if (tab != voyageTab) {
    await tester.tap(find.byKey(Key('tab.$tab')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

class _NoCommands implements CommandSink {
  @override
  void send(Command command) {}
}

Future<void> _save(WidgetTester tester, String path, _Device device) async {
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: device.dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
