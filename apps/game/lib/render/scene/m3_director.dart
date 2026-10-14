import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 전투 M3 연출: 스킬·화면 스킬·계열별 궁극기·분열·부활·수중 장판 (docs/specs/render-m3-fx.md).
///
/// 화면 스킬은 `SkillCast.scope == 'screen'`, 장판은 `ZoneSpawned`로 받는다 (계약 render-m3-events A·C).
class M3Director {
  M3Director(this.scene)
    : _skills = {
        for (final f in scene.tables.skills.families) f.skill.id: f.skill,
        for (final s in scene.tables.skills.crewSkills) s.id: s,
      };

  final BattleScene scene;
  final Map<String, SkillDef> _skills;

  FxMapTable get _fx => scene.fx;

  // 궁극기 rain 패턴의 결정론적 흩뿌림 (화면 안 x 80~300, y 40~130).
  static const _rainLeft = 80.0;
  static const _rainSpanX = 220;
  static const _rainTop = 40.0;
  static const _rainSpanY = 90;
  static const _rainPrimeX = 97;
  static const _rainPrimeY = 53;
  static const _rainTickX = 31;
  static const _rainTickY = 17;
  static const _splitPopScale = 0.5;
  static const _screenScope = 'screen';

  void onSkill(SkillCast e) {
    final skill = _skills[e.skillId];
    if (skill?.shape == 'ship') {
      scene
        ..spawnEffect(skill!.fx, kShipCenterX, kShipCenterY)
        ..shipHealMs = _fx.shipSkill.number('healFlashMs')
        ..shipBuffMs = skill.raw.numberOr('buffSec', 0) * Duration.millisecondsPerSecond;
      return;
    }
    final sheet = skill?.fx;
    if (e.scope == _screenScope) {
      _screenSkill(sheet);
      return;
    }
    if (sheet != null) scene.spawnEffect(sheet, e.x, e.y, scale: _fx.skillFxScale);
  }

  void _screenSkill(String? sheet) {
    if (scene.settings.flash) scene.screenFlashMs = _fx.screenSkill.number('flashMs');
    final big = scene.juice.shake['ultimate']!;
    scene.shake.triggerPx(big.px * _fx.screenSkill.number('shakeScale'), big.ms);
    if (sheet == null) return;
    var n = 0;
    for (var k = 0; k < scene.poseCount && n < scene.juice.maxEffects; k++) {
      final p = scene.poses[k];
      if (p.x > kLogicalWidth) continue;
      scene.spawnEffect(sheet, p.x, p.y);
      n++;
    }
  }

  void onUltimate(UltimateCast e, int index) {
    final pattern = _fx.ultimates[e.ultimateId];
    if (pattern == null) {
      final id = _fx.fxFor('ultimateCast');
      if (id != null) scene.spawnEffect(id, kUltimateX, kUltimateY);
      return;
    }
    final d = pattern.durationMs;
    final gap = d / pattern.count;
    switch (pattern.kind) {
      case UltimatePatternKind.sweep:
        scene.spawnEffect(pattern.fx, 0, kUltimateY, durationMs: d, vx: kLogicalWidth / d);
      case UltimatePatternKind.rain:
        for (var i = 0; i < pattern.count; i++) {
          final x = _rainLeft + (i * _rainPrimeX + index * _rainTickX) % _rainSpanX;
          final y = _rainTop + (i * _rainPrimeY + index * _rainTickY) % _rainSpanY;
          scene.spawnEffect(pattern.fx, x, y, delayMs: i * gap);
        }
      case UltimatePatternKind.strikes:
        var n = 0;
        for (var k = 0; k < scene.poseCount && n < pattern.count; k++) {
          final p = scene.poses[k];
          if (p.x > kLogicalWidth) continue;
          scene.spawnEffect(pattern.fx, p.x, p.y, delayMs: n * gap);
          n++;
        }
      case UltimatePatternKind.volley:
        final step = (kLogicalWidth - kShipNoseX) / (pattern.count + 1);
        for (var i = 0; i < pattern.count; i++) {
          scene.spawnEffect(pattern.fx, kShipNoseX + step * (i + 1), kShipNoseY, delayMs: i * gap);
        }
    }
  }

  /// 수중 장판: 남은 틱 동안 원을 그린다.
  void onZone(ZoneSpawned e) => scene.spawnZone(e.x, e.y, e.radius, e.ticks.toDouble());

  /// 분열(처치 자리 근처 새 id)과 부활(Kill 없이 hpRatio 상승)을 앞 틱과 비교해 찾는다.
  void detectSplitRevive(RecordedTick tick, int index) {
    final player = scene.player;
    final near = _fx.split.number('nearPx');
    for (final ev in tick.events) {
      if (ev is! Kill) continue;
      var born = 0;
      for (final en in tick.frame.enemies) {
        if (player.enemyAt(index - 1, en.id) != null) continue;
        if ((en.x - ev.x).abs() <= near && (en.y - ev.y).abs() <= near) born++;
      }
      if (born == 0) continue;
      scene.stats.splitPops++;
      final sheet = _fx.split.str('fx');
      scene
        ..spawnEffect(sheet, ev.x - near, ev.y, scale: _splitPopScale)
        ..spawnEffect(sheet, ev.x + near, ev.y, scale: _splitPopScale);
    }
    final minRise = _fx.revive.number('minRise');
    for (final en in tick.frame.enemies) {
      final before = player.enemyAt(index - 1, en.id);
      if (before == null || en.hpRatio - before.hpRatio < minRise || _killed(tick, en.id)) continue;
      scene.stats.revives++;
      scene
        ..spawnEffect(_fx.revive.str('fx'), en.x, en.y)
        ..hitEnemy(en.id);
    }
  }

  /// 보호막이 깨진 적(앞 틱 shielded → 지금 아님)에 깨짐 연출.
  void detectShieldBreak(RecordedTick tick, int index) {
    final shield = _fx.shield;
    for (final en in tick.frame.enemies) {
      if (en.shielded || !(scene.player.enemyAt(index - 1, en.id)?.shielded ?? false)) continue;
      scene.stats.shieldBreaks++;
      final color = _shieldColor ??= parseArgb(shield.str('color'), 'shield.color');
      final n = shield.integer('breakCount');
      for (var k = 0; k < n; k++) {
        final dx = (k - (n - 1) / 2) * _shardGapPx;
        scene.spawnEffect(shield.str('breakFx'), en.x + dx, en.y - dx.abs() / 2)?.color = color;
      }
    }
  }

  int? _shieldColor;
  static const _shardGapPx = 8.0;

  static bool _killed(RecordedTick tick, int id) {
    for (final ev in tick.events) {
      if (ev is Kill && ev.targetId == id) return true;
    }
    return false;
  }
}
