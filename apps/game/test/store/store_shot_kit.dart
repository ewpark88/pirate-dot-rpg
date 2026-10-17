import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import '../ui/ui_harness.dart' show voyageTab;

// 스토어 스크린샷 도구(store_shots_test.dart가 쓴다 — 기기 크기·실제 엔진 기록·장면 고르기·위젯 띄우기·PNG 저장).

/// 스크린샷 기기. 물리 픽셀은 모두 9:16(Play 규격). 전장은 물리 픽셀 정수배라 도트가 선명하다.
class ShotDevice {
  const ShotDevice(this.width, this.height, this.dpr, this.dir);

  final double width;
  final double height;
  final double dpr;

  /// `build/store/screens/` 아래 하위 폴더(휴대전화는 예전 경로 그대로).
  final String dir;

  Size get logical => Size(width / dpr, height / dpr);
}

const shotDevices = {
  'phone': ShotDevice(1080, 1920, 2.625, ''), // 411×731dp, 흔한 Pixel
  'tablet7': ShotDevice(1440, 2560, 2.4, 'tablet7/'), // 600×1067dp
  'tablet10': ShotDevice(1800, 3200, 2.25, 'tablet10/'), // 800×1422dp
};
const _sea = Color(0xFF1B4F72); // BattleGame.backgroundColor와 같게
final GlobalKey _shotKey = GlobalKey();

/// [fever]: 피버 게이지를 미리 채워 둔다(피버 첫 일격 장면용 — 실제로는 처치로 차는 데 시간이 걸린다).
/// [fleet]: 출전 선원을 정해 둔다(연쇄 번개 장면 — 볼트·범고래·수달).
GameState shotFixture(String name, {double? fever, String? skin, List<String>? fleet}) {
  final json = jsonDecode(File('../../fixtures/states/$name.json').readAsStringSync()) as Map<String, dynamic>;
  if (fever != null) (json['progress'] as Map<String, dynamic>)['fever'] = fever;
  var s = GameState.fromJson(json).copyWith(clearTutorial: true);
  if (fleet != null) s = s.copyWith(fleet: fleet, fleetInit: true);
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
bool inCamera(GameTables t, double x, double y, {double inner = 1}) {
  final top = t.waves.raw.obj('top');
  return (x - top.number('shipX')).abs() <= top.number('viewWidth') / 2 * inner &&
      (y - top.number('shipY')).abs() <= top.number('viewHeight') / 2 * inner;
}

/// 샘플 상태에서 실제 엔진을 [ticks]만큼 돌린 기록.
class ShotRun {
  ShotRun(this.tables, GameState start, {required int ticks, Map<int, List<Command>> commands = const {}}) {
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
  ShotMoment after(bool Function(GameEvent e) match, {required int ticks}) {
    final at = this.ticks.indexWhere((t) => t.events.any(match));
    if (at < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    return _at(at + ticks);
  }

  /// [match]가 난 틱들 가운데 [ticks] 뒤 화면 안(x < 320) 적이 가장 많은 순간 (앞쪽 [before] 틱 안에서).
  ShotMoment best(bool Function(GameEvent e) match, {required int ticks, int? before}) {
    var bestAt = -1;
    var most = -1;
    final end = (before ?? this.ticks.length) - ticks;
    for (var i = 0; i < end && i + ticks < this.ticks.length; i++) {
      if (!this.ticks[i].events.any(match)) continue;
      // 처치가 카메라 안쪽(가장자리 20% 밖 제외)에서 났을 때만(가장자리에서 나면 연출이 잘린다) — 탑다운 카메라 기준.
      final kills = this.ticks[i].events.whereType<Kill>().toList();
      if (kills.isNotEmpty && !kills.every((k) => inCamera(tables, k.x, k.y, inner: 0.8))) continue;
      final n = this.ticks[i + ticks].frame.enemies.where((e) => inCamera(tables, e.x, e.y)).length;
      if (n > most) (bestAt, most) = (i, n);
    }
    if (bestAt < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    return _at(bestAt + ticks);
  }

  /// [after] 이벤트 뒤 [skip]틱부터, 화면이 [frame]을 만족하고 앞 [quietTicks] 안에 [quiet] 이벤트가 없는 첫 틱.
  ShotMoment firstClear({
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

  /// [match]가 처음 난 틱 뒤 [from]~[to]틱 가운데 카메라 안 적이 가장 많은 순간(피버 무리처럼 화면이 차는 때).
  ShotMoment crowded(bool Function(GameEvent e) match, {required int from, required int to}) {
    final start = ticks.indexWhere((t) => t.events.any(match));
    if (start < 0) throw StateError('기록에 원하는 이벤트가 없다 — 틱 수를 늘린다');
    var bestAt = start + from;
    var most = -1;
    for (var i = start + from; i <= start + to && i < ticks.length; i++) {
      final n = ticks[i].frame.enemies.where((e) => inCamera(tables, e.x, e.y)).length;
      if (n > most) (bestAt, most) = (i, n);
    }
    return _at(bestAt);
  }

  /// 정해진 틱 (탭 화면 배경용).
  ShotMoment at(int tick) => _at(tick);

  ShotMoment _at(int tick) {
    final target = tick.clamp(0, ticks.length - 1);
    final from = (target - 60).clamp(0, target);
    return ShotMoment(ticks.sublist(from, target + 1), states[target]);
  }
}

class ShotMoment {
  const ShotMoment(this.ticks, this.state);

  final List<RecordedTick> ticks;
  final GameState state;

  ShotMoment withState(GameState s) => ShotMoment(ticks, s);

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
    // 탑다운: 앱(BattleGame)과 같이 캔버스를 상자 dp 그대로 두고 탑다운 카메라로 그린다(옆모습은 T4-3에서 지워짐).
    painter.scene.layout = battleFrameFor(size, dpr);
    painter.paintTop(canvas, topFrameFor(size, dpr));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // 시트가 열려 상자가 줄면 다시 그린다(앱과 같은 크기)
}

Future<void> pumpShot(
  WidgetTester tester,
  GameState state, {
  required Locale locale,
  required int tab,
  required ScenePainter painter,
  required ShotDevice device,
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

Future<void> saveShot(WidgetTester tester, String path, ShotDevice device) async {
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: device.dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
