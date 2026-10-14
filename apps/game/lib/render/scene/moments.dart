import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 해역 보스 컷인 상태. UI가 [kind]·[progress]를 보고 이름을 얹는다.
class CutInState {
  String? kind;
  double ageMs = 0;
  double totalMs = 0;

  bool get active => kind != null && ageMs < totalMs;
  double get progress => totalMs <= 0 ? 1 : (ageMs / totalMs).clamp(0.0, 1.0);
}

/// '큰 순간' 연출 (docs/specs/render-moments.md): 해역 보스 첫 등장 컷인, 배 등급 승급 빛기둥, 해역 이동 해일.
/// 배 등급·해역·해역 보스는 모두 `frame.stage`에서 테이블로 구한다(계약 G 거절 — 파생값).
/// 연출만 한다 — 재생 속도·기록은 그대로.
class Moments {
  Moments(this.scene);

  final BattleScene scene;
  final cutIn = CutInState();
  final Set<String> _seenBosses = {};

  /// 지금 배 등급 id (`ship_tiers.json`). 첫 프레임 전에는 빈 문자열.
  String shipTierId = '';

  /// 승급 빛기둥 남은 시간(ms)과 지금까지 횟수.
  double pillarMs = 0;
  int pillarCount = 0;
  bool _seenFrame = false;

  /// 매 화면 프레임: 해역(배경·bgm·해일)·보물상자·배 등급.
  void onFrame(BattleView f) {
    if (scene.backdrop.setStage(f.stage)) {
      scene.sound.bgm(scene.backdrop.bgmFor(f.stage));
      if (_seenFrame) _regionSweep();
    }
    scene.chest.update(f.chest, scene.fx.chest, scene.clockMs);
    final tier = scene.tables.shipTiers.tierAt(f.stage).id;
    if (tier != shipTierId) {
      if (_seenFrame && pillarMs <= 0) _tierUp();
      shipTierId = tier;
    }
    _seenFrame = true;
  }

  /// `ShipTierUp` 이벤트 — 같은 순간 등급 변화와 겹치면 한 번만.
  void onTierUp(String tierId) {
    if (pillarMs > 0 && tierId == shipTierId) return;
    shipTierId = tierId;
    _tierUp();
  }

  /// 해역 보스 첫 등장이면 컷인.
  void onBossSpawned(String kind, int stage) {
    if (kind != scene.tables.regions.regionAt(stage).regionBoss || !_seenBosses.add(kind)) return;
    final c = scene.fx.cutIn;
    cutIn
      ..kind = kind
      ..ageMs = 0
      ..totalMs = c.number('inMs') + c.number('holdMs') + c.number('outMs');
  }

  /// 운영자: 컷인 다시 보기.
  void resetSeenBosses() => _seenBosses.clear();

  void update(double dtMs) {
    if (cutIn.active) cutIn.ageMs += dtMs;
    if (pillarMs > 0) pillarMs -= dtMs;
  }

  void reset() {
    cutIn.kind = null;
    pillarMs = 0;
  }

  void _tierUp() {
    final p = scene.fx.pillar;
    pillarMs = p.number('ms');
    pillarCount++;
    scene
      ..spawnEffect('level_up', kShipCenterX, kShipTop, scale: p.number('fxScale'))
      ..shipFlashMs = scene.juice.flashFrames * kFrameMs;
  }

  void _regionSweep() {
    final s = scene.fx.regionSweep;
    final d = s.number('durationMs');
    scene.spawnEffect(s.str('fx'), 0, kUltimateY, durationMs: d, vx: kLogicalWidth / d);
  }
}
