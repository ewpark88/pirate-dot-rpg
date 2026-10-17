import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart' show bossScaleOf;
import 'package:game_data/game_data.dart' show parseArgb;
import 'package:pirate_dot/render/hd/hd_boss_shatter.dart';
import 'package:pirate_dot/render/hd/hd_muzzle.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_bestiary.dart';
import 'package:pirate_dot/render/top/top_boss_loot.dart';
import 'package:pirate_dot/render/top/top_boss_pattern.dart';
import 'package:pirate_dot/render/top/top_bounty.dart';
import 'package:pirate_dot/render/top/top_break.dart';
import 'package:pirate_dot/render/top/top_crew_fx.dart';
import 'package:pirate_dot/render/top/top_emerge.dart';
import 'package:pirate_dot/render/top/top_family_v3.dart';
import 'package:pirate_dot/render/top/top_fast_sail.dart';
import 'package:pirate_dot/render/top/top_fever_strike.dart';
import 'package:pirate_dot/render/top/top_glow.dart';
import 'package:pirate_dot/render/top/top_impact.dart';
import 'package:pirate_dot/render/top/top_juice.dart';
import 'package:pirate_dot/render/top/top_muzzle.dart';
import 'package:pirate_dot/render/top/top_resupply.dart';
import 'package:pirate_dot/render/top/top_shots.dart';
import 'package:pirate_dot/render/top/top_slash.dart';
import 'package:pirate_dot/render/top/top_traits.dart';

/// 탑다운 배 충돌 연출 (사용자 '적들이 배에 부딪히지 않는다' — 엔진은 닿는데 눈에 안 보였다, S1):
/// 때린 적이 배 쪽으로 툭 박고(돌진), 닿은 자리에 물보라·나뭇조각이 튄다. 엔진 무관 — ShipDamaged fromX/fromY.
class TopHits {
  /// 적 포탄(보스 BossFired·원거리 적) — 배로 날아와 폭발.
  final shots = TopShots();

  /// 강습 근접 휘두르기·베기 자국.
  final slash = TopSlash();

  /// 보스 행동 v2 예고·동작.
  final boss = TopBossPattern();

  /// 선원 특성(연쇄 번개·처형·충전·추적) — 표가 필요해 EventDirector가 처음 만든다.
  TopTraits? traits;

  /// 보스 처치 HD 터짐(카툰 섬광·몸 조각·연기).
  final shatter = HdBossShatter();

  /// HD 원거리 적 발사 빛(쏘는 부위).
  final muzzle = HdMuzzle();

  /// 지금까지 띄운 카드 수(CardGranted → 연출, 실제 흐름 회귀 테스트가 센다).
  int cardsShown = 0;

  /// 배 스킨 포구 화염 색(TopScenePainter가 프레임마다, 없으면 등급 색).
  int? skinMuzzle;

  /// 디자인 개편 발광: 스킬 마법진(배 밑).
  final glow = TopGlow();

  /// 도감 v2 보스 패턴(먹물·삼키기·분열).
  final bestiary = TopBestiary();

  /// 솟아오르기 예고(EnemyEmerging).
  final emerges = TopEmerge();

  /// 빠른 항해 보급 상자(ShipResupplied).
  final resupply = TopResupply();

  /// 피버 첫 일격(UltimateCast).
  final feverStrike = TopFeverStrike();

  /// 보스 브레이크 쓰러짐(BossBroken).
  final breaks = TopBreak();

  /// 보스 처치 보상 터짐(피드백 #18).
  final loot = TopBossLoot();

  /// 범위 공격 임팩트 v2.
  final impact = TopImpact();

  /// 선원 개성 v2(보호막·낙뢰·빗나감·북 파동).
  final crew = TopCrewFx();

  /// 빠른 항해 돌파.
  final fast = TopFastSail();

  /// 현상금 사냥 B3.
  final bounty = TopBounty();

  /// 타격감 v3(히트스톱·방향 흔들림·넉백·처치 조각).
  final juice = TopJuice();

  /// 계열 행동 v3(출격·레이저).
  final family = TopFamilyV3();

  /// 그림 은행(출격 초상) — ScenePainter.paintTop이 넣는다.
  SpriteDraw? sprites;

  /// 적 id → 돌진 시작 시각(장면 ms).
  final Map<int, double> _lunge = {};
  final List<_Spot> _spots = [];

  static const lungeMs = 120.0;
  static const lungeUnits = 4.0;
  static const spotMs = 420.0;
  static const _maxSpots = 12;

  /// 배가 (fromX, fromY)에서 맞음: 가장 가까운 적이 돌진, 선체 가장자리(배 중심에서 그쪽으로 최대 12단위)에 물보라.
  void hit(BattleScene s, double fromX, double fromY) {
    final now = s.clockMs;
    var best = -1;
    var bestD = double.infinity;
    for (var k = 0; k < s.poseCount; k++) {
      final e = s.poses[k];
      final d = (e.x - fromX) * (e.x - fromX) + (e.y - fromY) * (e.y - fromY);
      if (d < bestD) (best, bestD) = (e.id, d);
    }
    if (best >= 0) _lunge[best] = now;
    final ship = s.topShip;
    final dx = fromX - ship.dx;
    final dy = fromY - ship.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final reach = math.min<double>(len, 12);
    final at = len < 1e-6 ? ship : ship + Offset(dx / len * reach, dy / len * reach);
    if (_spots.length >= _maxSpots) _spots.removeAt(0);
    _spots.add(_Spot(at.dx, at.dy, now, math.atan2(dy, dx)));
    if (_lunge.length > 64) _lunge.removeWhere((_, t) => now - t > lungeMs);
  }

  double _flashAt = -1000000000;
  static const _flashGapMs = 500.0; // 배 피격 틴트 간격(사용자 '번쩍임 자제' — 0.5초 이상)

  /// 배 번쩍을 새로 켜도 되는가(연달아 맞을 때 배가 계속 하얗게 보이지 않게 [_flashGapMs]마다 한 번). 켜면 시각을 적는다.
  bool takeFlash(double now) {
    if (now - _flashAt < _flashGapMs) return false;
    _flashAt = now;
    return true;
  }

  /// 적 [id]의 돌진 거리(단위, 0이면 없음): 앞으로 갔다 돌아옴 sin(π·t).
  double lungeOf(int id, double now) {
    final t0 = _lunge[id];
    if (t0 == null) return 0;
    final t = (now - t0) / lungeMs;
    if (t < 0 || t >= 1) return 0;
    return lungeUnits * math.sin(math.pi * t);
  }

  final _paint = Paint()..isAntiAlias = false;
  static const _chip = [0xFF8A5A30, 0xFFB57B44, 0xFF6B4423];

  /// 물보라(흰·하늘 점이 둥글게 퍼짐)·나뭇조각(배 바깥쪽으로 튐)·작은 번쩍. 전장 좌표.
  void paint(Canvas c, double now, {required bool flash, bool powerSave = false, Offset ship = Offset.zero}) {
    glow.paint(c, now, ship, lite: lite || powerSave);
    muzzles.paint(c, now, flash: flash, powerSave: powerSave || lite);
    _paintUpgrade(c, ship, now);
    emerges.paint(c, now);
    bestiary.paint(c, now);
    slash.paint(c, now);
    _spots.removeWhere((p) => now - p.ms >= spotMs);
    for (final p in _spots) {
      final t = ((now - p.ms) / spotMs).clamp(0.0, 1.0);
      final fade = 1 - t;
      if (flash && t < 0.25) {
        _paint.color = Color.fromARGB((120 * (1 - t / 0.25)).round(), 255, 226, 122); // 흰 대신 옅은 노랑
        c.drawCircle(Offset(p.x, p.y), 5 * (1 - t), _paint);
      }
      for (var k = 0; k < 8; k++) {
        final a = p.angle + k * math.pi / 4 + 0.2;
        final r = 3 + 9 * t;
        _paint.color = Color.fromARGB((255 * fade).round(), k.isEven ? 255 : 190, k.isEven ? 255 : 232, 255);
        final size = t < 0.5 ? 2.0 : 1.0;
        c.drawRect(
          Rect.fromLTWH((p.x + math.cos(a) * r).roundToDouble(), (p.y + math.sin(a) * r).roundToDouble(), size, size),
          _paint,
        );
      }
      for (var k = 0; k < 4; k++) {
        final a = p.angle + (k - 1.5) * 0.45;
        final r = 2 + 13 * t;
        _paint.color = Color(_chip[k % 3]).withValues(alpha: fade);
        c.drawRect(
          Rect.fromLTWH((p.x + math.cos(a) * r).roundToDouble(), (p.y + math.sin(a) * r).roundToDouble(), 2, 1),
          _paint,
        );
      }
    }
  }

  /// 가벼운 연출(입자 절반): 절전이거나 시트가 전장을 가렸을 때 — TopScenePainter가 프레임마다 넣는다(사용자 '모두 신화' 버벅임).
  bool lite = false;

  /// 발사 임팩트(포구 섬광·고리·연기).
  final muzzles = TopMuzzle();

  final _ring = Paint()..style = PaintingStyle.stroke;

  static const _upMs = 320.0;

  /// 빠른 강화 빛 줄기 시작(장면 ms).
  double upgradeAt = -1000000000;

  /// 아래(강화 버튼 쪽)에서 배로 올라오는 금빛 줄기 + 배 둘레 반짝 고리. 배 중심 [ship], 전장 좌표.
  void _paintUpgrade(Canvas c, Offset ship, double now) {
    final age = now - upgradeAt;
    if (age < 0 || age >= _upMs) return;
    final t = age / _upMs;
    final head = ship.dy + 90 * (1 - math.min(1, t * 2.5));
    final fade = 1 - t;
    _paint.color = Color.fromRGBO(255, 216, 74, 0.35 * fade);
    c.drawRect(Rect.fromLTRB(ship.dx - 4, head, ship.dx + 4, ship.dy + 90), _paint);
    _paint.color = Color.fromRGBO(255, 246, 200, 0.8 * fade);
    c.drawRect(Rect.fromLTRB(ship.dx - 1, head, ship.dx + 1, ship.dy + 90), _paint);
    if (t > 0.35) {
      final k = (t - 0.35) / 0.65;
      _ring
        ..strokeWidth = 1.5
        ..color = Color.fromRGBO(255, 216, 74, 1 - k);
      c.drawCircle(ship, 10 + 16 * k, _ring);
    }
  }

  /// 적 위 층(전장 좌표): 범위 임팩트·적 포탄·돌파 사격·현상금 핀·보스 예고·선원 개성 — TopScenePainter가 적 다음에 부른다.
  void paintOver(Canvas c, BattleScene s, double now, double shipR, Offset? Function(int id) bossAt) {
    final view = s.frame;
    final flash = s.settings.flash;
    final ship = s.topShip;
    juice.paint(c, now, lite: lite, fever: view.feverTicksLeft > 0);
    bestiary.paintOver(c, now);
    traits
      ?..ship = ship
      ..paint(c, now, view, s.poses, s.poseCount, lite: lite);
    impact.paint(c, now, flash: flash, lite: lite, ship: ship);
    family.paint(c, now, ship, const Rect.fromLTWH(0, 0, 300, 520), sprites);
    shots.paint(c, now, flash: flash);
    fast.paintWorld(c, now, ship);
    bounty.paintWorld(c, now, s.poses, s.poseCount, active: view.bounty != null);
    boss.paint(c, now, ship, bossAt, flash: flash);
    crew
      ..fever(view.fever, drummer: view.fleet.any((f) => f.crewId == 'pumpum'), now: now)
      ..paint(c, now, ship, shipR, view.shipShield, s.poses, s.poseCount, flash: flash);
    shatter.paint(c, now);
    loot.paint(c, now, ship, sprites, flash: flash);
    feverStrike.paintWorld(c, now, lite: lite);
    resupply.paint(c, now, ship);
  }

  /// 화면 좌표 덮개: 빠른 항해 띠·현상금 포스터·피버 첫 일격 컷인.
  void paintScreen(Canvas c, Size box, double now, SpriteDraw sprites, {required bool flash}) {
    fast.paintScreen(c, box, now, flash: flash);
    bounty.paintScreen(c, box, now, sprites);
    feverStrike.paintScreen(c, box, now, sprites);
  }

  /// HD 처치 터짐: 그 보스 색(fx_map bossLook.color)·크기(그림 칸 반 × waves.top.bossScale)로 조각·연기·섬광.
  void bossKilled(BattleScene s, int id, Offset at, {required bool lite}) {
    for (var k = 0; k < s.poseCount; k++) {
      final p = s.poses[k];
      if (p.id != id) continue;
      final look = s.fx.bossLook[p.kind];
      final r = (look?.number('w') ?? 56) / 2 * bossScaleOf(s.tables, p.kind);
      shatter.burst(s.clockMs, at, r, parseArgb(look?.strOrNull('color') ?? '#B04A3A', 'bossLook.color'), lite: lite);
      return;
    }
  }

  void clear() {
    shatter.clear();
    family.clear();
    juice.clear();
    muzzles.clear();
    bounty.clear();
    fast.clear();
    crew.clear();
    impact.clear();
    boss.clear();
    loot.clear();
    breaks.clear();
    feverStrike.clear();
    resupply.clear();
    slash.clear();
    emerges.clear();
    bestiary.clear();
    glow.clear();
    traits?.clear();
    upgradeAt = -1000000000;
    shots.clear();
    _flashAt = -1000000000;
    _lunge.clear();
    _spots.clear();
  }
}

class _Spot {
  _Spot(this.x, this.y, this.ms, this.angle);
  final double x;
  final double y;
  final double ms;
  final double angle;
}
