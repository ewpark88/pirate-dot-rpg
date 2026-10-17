import 'dart:ui' show Offset;

import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

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

  /// 배 부품 외형이 바뀐 부위와 남은 빛(ms) — ShipLookChanged (S2). 그리는 쪽이 그 부위 덧그림을 반짝인다.
  String? glowPart;
  double glowMs = 0;

  /// 대포 발사 시각 (장면 시계 ms) — 반동. 포구 화염 지연만큼 미래일 수 있다.
  double cannonFiredAtMs = -1000000000;

  /// 피버 시작 금빛 번쩍 남은 시간(ms).
  double feverFlashMs = 0;

  /// 무리전 침몰(배 HP 0, 엔진이 배를 고치고 파를 다시) 연출 남은 시간(ms): 앞 절반 기울며 가라앉고, 뒤 절반 고쳐져 떠오른다.
  double sinkMs = 0;

  /// 큰 띠(심연의 탑 '12F'·보스 러시 'BOSS RUSH'·'LAST BOSS!'): 가운데 보라 띠 + 큰 글자 + 위 작은 글자.
  String bannerText = '';
  String bannerSub = '';
  double bannerMs = 0;
  double bannerTotal = 1600;
  bool bannerHot = false; // 붉은 띠(마지막 보스)

  void banner(String text, {String sub = '', double ms = 1600, bool hot = false}) {
    bannerText = text;
    bannerSub = sub;
    bannerMs = bannerTotal = ms;
    bannerHot = hot;
  }

  /// 심연의 탑 층 띠(S1): 층 시작 '12F' 1.6초, 클리어면 위에 'CLEAR!'.
  void onTowerFloor(int floor, {bool cleared = false}) => banner('${floor}F', sub: cleared ? 'CLEAR!' : '');

  /// 보스전 누계(S1 '보스전도 핵앤슬래시' — 콤보는 피버 전용이라 보스전엔 'TOTAL'): 연속 타격 피해 합, 1.5초 끊기면 새로.
  BigNum bossTotal = BigNum.zero;
  double bossTotalAt = -1000000000;
  static const bossTotalGapMs = 1500.0;
  void bossHit(BigNum amount, double now) {
    if (now - bossTotalAt > bossTotalGapMs || now < bossTotalAt) bossTotal = BigNum.zero;
    bossTotal = bossTotal + amount;
    bossTotalAt = now;
  }

  /// 최근 처치 자리(최대 [_killMax]) — 무리 처치(MultiKill) 때 금화 터짐을 그 자리들에 뿌린다.
  final recentKills = <Offset>[];
  static const _killMax = 16;
  void killAt(double x, double y) {
    if (recentKills.length >= _killMax) recentKills.removeAt(0);
    recentKills.add(Offset(x, y));
  }

  /// 요일 던전(S2): 시작 띠 'MON 3' + 그 날 계열(PIERCE · LASER), 그 계열 착탄은 크게·금 테(TopImpact).
  Set<String> dungeonFamilies = const {};
  void onDungeonStarted(String group, int step, List<String> families) {
    dungeonFamilies = scene.topHits.impact.hotFamilies = families.toSet();
    banner('${group.toUpperCase()} $step', sub: families.map((f) => f.toUpperCase()).join(' · '), ms: 1800);
  }

  void onDungeonEnded({required bool cleared}) {
    dungeonFamilies = scene.topHits.impact.hotFamilies = const {};
    banner(cleared ? 'CLEAR!' : 'FAILED', ms: 1400, hot: !cleared);
  }

  /// 보스 러시(S5): 시작 'BOSS RUSH 1/n', 보스 하나 쓰러질 때마다 다음 번호 짧게, 마지막(대보스) 앞은 붉은 'LAST BOSS!' 길게.
  int rushTotal = 0;
  void onRushStarted(int total) {
    rushTotal = total;
    banner('BOSS RUSH', sub: '1/$total', ms: 1500);
  }

  void onRushBossDown(int index) {
    final next = index + 2; // 다음 보스 번호(1부터)
    if (rushTotal <= 0 || next > rushTotal) return;
    next == rushTotal
        ? banner('LAST BOSS!', sub: '$next/$rushTotal', ms: 2200, hot: true)
        : banner('$next/$rushTotal', sub: 'NEXT!', ms: 1000);
  }

  void onShipSunk() {
    if (sinkMs > 0) return;
    sinkMs = scene.fx.raw.obj('shipHp').number('sinkMs');
  }

  void onPartUp(String part) {
    glowPart = part;
    glowMs = scene.fx.raw.obj('shipParts').number('glowMs');
    final fx = scene.fx.fxFor('shipLookChanged');
    if (fx != null) scene.spawnEffect(fx, scene.shipCenter.dx, scene.shipCenter.dy - 8);
  }

  /// 해역 보스 첫 등장이면 컷인.
  void onBossSpawned(String kind, int stage) {
    scene.topHits.glow.bossRiseAt = scene.clockMs; // 개편 ③ 보스 등장 빛기둥(모든 보스)
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
    if (bannerMs > 0) bannerMs -= dtMs;
    if (cutIn.active) cutIn.ageMs += dtMs;
    if (pillarMs > 0) pillarMs -= dtMs;
    if (glowMs > 0) glowMs -= dtMs;
    if (feverFlashMs > 0) feverFlashMs -= dtMs;
    if (sinkMs > 0) {
      final half = scene.fx.raw.obj('shipHp').number('sinkMs') / 2;
      final before = sinkMs;
      sinkMs -= dtMs;
      // 반쯤 가라앉았을 때 수리 반짝(떠오르기 시작).
      if (before > half && sinkMs <= half) scene.spawnEffect('level_up', scene.shipCenter.dx, scene.shipCenter.dy);
    }
  }

  void reset() {
    cutIn.kind = null;
    pillarMs = 0;
  }

  void _tierUp() {
    final p = scene.fx.pillar;
    pillarMs = p.number('ms');
    pillarCount++;
    final at = scene.shipCenter;
    scene
      ..spawnEffect('level_up', at.dx, at.dy + kShipHeight / 2, scale: p.number('fxScale'))
      ..shipFlashMs = scene.juice.flashFrames * kFrameMs;
  }

  void _regionSweep() {
    final s = scene.fx.regionSweep;
    final d = s.number('durationMs');
    scene.spawnEffect(s.str('fx'), 0, kUltimateY, durationMs: d, vx: kLogicalWidth / d);
  }
}
