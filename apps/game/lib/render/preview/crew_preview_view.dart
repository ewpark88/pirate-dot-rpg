import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 선원 공격 미리보기 작은 전장(S1 2026-10-17): 공용 하네스 [CrewPreview](앱 엔진과 따로 — 저장·진행에 안 닿음)를
/// 이 위젯의 Ticker로 돌려 본 전투와 같은 장면·그림(BattleScene·ScenePainter.paintTop)으로 그린다.
/// 위젯이 사라지면(창 닫힘) Ticker가 멈춰 엔진도 멈춘다. [lite](절전·발열)면 juice powerSave.fps로만 장면을 진행한다.
/// [crewId]·[level]이 바뀌면(등급 탭) 처음부터 다시. 창은 16:9(폭 100%)를 기대한다 — 보이는 전장 폭 [_PreviewPainter._viewUnits].
class CrewPreviewView extends StatefulWidget {
  const CrewPreviewView({
    required this.tables,
    required this.crewId,
    required this.level,
    this.sprites,
    this.lite = false,
    this.play = true,
    super.key,
  });

  final GameTables tables;
  final String crewId;
  final int level;

  /// 본 전투의 아트 팩(없으면 플레이스홀더 — 같은 그림을 두 번 읽지 않는다).
  final SpriteBank? sprites;
  final bool lite;

  /// false면 첫 장면만 그리고 멈춘다(UI 시험·골든 — 끝없는 애니메이션이 pumpAndSettle을 막지 않게).
  final bool play;

  @override
  State<CrewPreviewView> createState() => _CrewPreviewViewState();
}

class _CrewPreviewViewState extends State<CrewPreviewView> with SingleTickerProviderStateMixin {
  late CrewPreview _engine;
  late BattleScene _scene;
  late ScenePainter _painter;
  bool _made = false;
  Ticker? _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  Duration _last = Duration.zero;
  var _tickAccum = 0.0;
  var _liteAccum = 0.0;

  /// 열자마자 보이는 장면까지 미리 돌리는 시간(초).
  static const _warmSec = 1.5;

  double get _tickMs => widget.tables.waves.tickMs.toDouble();

  @override
  void initState() {
    super.initState();
    _restart();
    if (widget.play) unawaited((_ticker = createTicker(_onFrame)).start());
  }

  void _restart() {
    _engine = CrewPreview(widget.tables, crewId: widget.crewId, level: widget.level);
    _scene = BattleScene(widget.tables, null);
    if (_made) _painter.dispose(); // 옛 장면 HD 텍스처를 바로 놓는다
    _made = true;
    _painter = ScenePainter(_scene)..sprites = widget.sprites;
    _tickAccum = 0;
    _liteAccum = 0;
    // 첫 화면부터 배·적·공격이 보이게 [_warmSec]초를 미리 돌린다(멈춘 첫 장면 — UI 시험·골든 — 도 빈 바다가 아니게).
    for (var i = 0; i <= _scene.juice.lookaheadTicks; i++) {
      _scene.push(_engine.step());
    }
    final warm = (_warmSec * Duration.millisecondsPerSecond / _tickMs).round();
    for (var i = 0; i < warm; i++) {
      _scene
        ..push(_engine.step())
        ..update(_tickMs);
    }
  }

  @override
  void didUpdateWidget(CrewPreviewView old) {
    super.didUpdateWidget(old);
    if (old.crewId != widget.crewId || old.level != widget.level || old.tables != widget.tables) {
      _restart();
    } else if (old.sprites != widget.sprites) {
      _painter.sprites = widget.sprites;
    }
  }

  void _onFrame(Duration now) {
    final dtMs = (now - _last).inMicroseconds / Duration.microsecondsPerMillisecond;
    _last = now;
    if (dtMs <= 0) return;
    _tickAccum += dtMs;
    while (_tickAccum >= _tickMs) {
      _tickAccum -= _tickMs;
      _scene.push(_engine.step());
    }
    var stepMs = dtMs;
    if (widget.lite) {
      _liteAccum += dtMs;
      if (_liteAccum < Duration.millisecondsPerSecond / _scene.juice.powerSaveFps) return;
      stepMs = _liteAccum;
      _liteAccum = 0;
    }
    _scene.update(stepMs);
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    if (_made) _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRect(
      child: CustomPaint(
        painter: _PreviewPainter(_painter, _scene, dpr, _repaint),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.painter, this.scene, this.dpr, Listenable repaint) : super(repaint: repaint);

  final ScenePainter painter;
  final BattleScene scene;
  final double dpr;

  /// 보이는 전장 폭(단위) — 본 전투(270)보다 넓게 줄여 작은 창에서도 보스(배 앞 standoff 100)·무리가 함께 보이게.
  /// 270 이상 540 미만이라 TopFrame 배율 k = 1(가상 상자 1단위 = 1dp).
  static const _viewUnits = 400.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 가상 상자(폭 _viewUnits dp, dpr 1): 보이는 전장(위 ~ 선원 줄 윗변)이 이 창 높이와 같게 — 선원 줄은 창 아래로 잘린다.
    // 보스전 카메라(배를 전장 78%로)·배 자리(63%)가 본 전투와 같은 비율로 창 안에서 움직인다.
    final scale = size.width / _viewUnits;
    final want = size.height / scale;
    final probe = topFrameFor(Size(_viewUnits, want), 1);
    final frame = topFrameFor(Size(_viewUnits, want + want - probe.fieldDp.height), 1);
    scene.layout = frame.band;
    canvas
      ..save()
      ..scale(scale);
    painter.paintTop(canvas, frame);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.painter != painter;
}
