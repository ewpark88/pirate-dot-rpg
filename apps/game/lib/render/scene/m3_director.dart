import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 전투 M3 연출: 스킬·화면 스킬·계열별 궁극기·분열·부활·수중 장판 (docs/specs/render-m3-fx.md).
///
/// 계약 요청 A·C가 main에 들어오기 전까지 임시 어댑터를 쓴다:
/// - 화면 스킬: 같은 틱 그 선원의 Damage 대상 수 ≥ 화면 안 적 × `screenSkill.adapterRatio`.
/// - 장판: underwater 계열 AttackFired 조준점에 계열 `attack.radius`, `zone.fallbackSec`.
class M3Director {
  M3Director(this.scene)
    : _skills = {
        for (final f in scene.tables.skills.families) f.skill.id: f.skill,
        for (final s in scene.tables.skills.crewSkills) s.id: s,
      },
      _underwaterRadius = _radiusOf(scene.tables, 'underwater');

  final BattleScene scene;
  final Map<String, SkillDef> _skills;
  final double _underwaterRadius;

  static double _radiusOf(GameTables t, String family) {
    for (final f in t.skills.families) {
      if (f.id == family) return f.attack.radius;
    }
    return 0;
  }

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

  void onSkill(SkillCast e, RecordedTick tick) {
    final skill = _skills[e.skillId];
    if (skill?.shape == 'ship') {
      scene
        ..spawnEffect(skill!.fx, kShipCenterX, kShipCenterY)
        ..shipHealMs = _fx.shipSkill.number('healFlashMs')
        ..shipBuffMs = skill.raw.numberOr('buffSec', 0) * Duration.millisecondsPerSecond;
      return;
    }
    final sheet = skill?.fx;
    if (_isScreenSkill(e, tick)) {
      _screenSkill(sheet);
      return;
    }
    if (sheet != null) scene.spawnEffect(sheet, e.x, e.y, scale: _fx.skillFxScale);
  }

  bool _isScreenSkill(SkillCast e, RecordedTick tick) {
    var onScreen = 0;
    for (final en in tick.frame.enemies) {
      if (en.x <= kLogicalWidth) onScreen++;
    }
    var hits = 0;
    for (final ev in tick.events) {
      if (ev is Damage && ev.crewId == e.crewId) hits++;
    }
    return onScreen > 1 && hits >= onScreen * _fx.screenSkill.number('adapterRatio');
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

  /// 임시 어댑터(계약 C 전): 수중 공격 조준점에 장판.
  void zoneFromAttack(AttackFired e) {
    if (e.family != 'underwater' || _underwaterRadius <= 0) return;
    final ticks = _fx.zone.number('fallbackSec') * Duration.millisecondsPerSecond / scene.player.tickMs;
    scene.spawnZone(e.x, e.y, _underwaterRadius, ticks);
  }

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

  static bool _killed(RecordedTick tick, int id) {
    for (final ev in tick.events) {
      if (ev is Kill && ev.targetId == id) return true;
    }
    return false;
  }
}
