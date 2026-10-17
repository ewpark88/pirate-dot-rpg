import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart' show bossScaleOf;
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

part 'top_enemies_fx.dart';

/// 그릴 그림 한 칸: 이미지·원본 칸·배율(HD는 world/cell)·HD 여부(부드러운 확대).
typedef _Spr = ({Image image, Rect src, double scale, bool hd});

/// 탑다운 적 그리기: 그림별 drawAtlas 묶음·헤엄 흔들림·돌진·돌발 이벤트. HD 종은 굽힌 시트(돌리지 않고 좌우만 뒤집기).
class TopEnemies {
  TopEnemies(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;
  static const _underwaterAlpha = 0.55;

  /// 보물 상선은 내 배보다 작게(사용자 스샷 '배 위에 겹쳐' — 경로는 S2가 배 밖 40단위로).
  static const _merchant = 'td_event:merchant_ship';
  static const _merchantScale = 0.55;

  /// 돌진(배를 때린 적이 배 쪽으로 툭): 배 중심 방향 단위 벡터 × 돌진 거리.
  Offset _lungeOf(int id, double x, double y, double clock) {
    final d = scene.topHits.lungeOf(id, clock);
    if (d == 0) return Offset.zero;
    final to = scene.topShip - Offset(x, y);
    final len = to.distance;
    return len < 1e-6 ? Offset.zero : to / len * d;
  }

  /// 적 그림 반지름(단위) — 상태 아이콘·보호막 고리 자리.
  double radiusOf(EnemyPose e) {
    final key = (e.boss ? _bossKeys : _enemyKeys)[e.kind] ??= _keyFor(e.kind, boss: e.boss);
    return (sprites.sheet(key)?.frameW ?? 12) / 2 * _boost(e.kind, boss: e.boss);
  }

  /// 그리는 배율: HD 잡몹 1.3(그림만), 보스는 엔진과 같은 waves.top.bossScale(대보스·해역·그 밖 — 충돌·standoff도 같은 값).
  double _boost(String kind, {required bool boss}) => boss
      ? (_bossBoost[kind] ??= bossScaleOf(scene.tables, kind))
      : (hdEnemies.containsKey(kind) ? HdSheets.enemyBoost : 1);
  final Map<String, double> _bossBoost = {};

  /// 그림(종류)별로 묶어 drawAtlas 한 번씩(150마리 60fps), 맞은 적은 흰 실루엣 묶음·물속은 반투명 붓.
  void paint(Canvas c, {required bool under, required Rect cull}) {
    for (final b in _batches.values.followedBy(_flashBatches.values).followedBy(_hotBatches.values)) {
      b.clear();
    }
    final clock = scene.clockMs;
    final lite = scene.topHits.lite;
    final crowd = scene.topHits.juice.crowd = scene.poseCount > 140; // 붐빔: 하나씩 그리는 연출을 줄인다
    _seen.clear();
    hdSheets
      ..cap = lite ? HdSheets.lowCell : HdSheets.maxCell
      ..plan(
        scene.frame.stage,
        scene.tables.regions,
        (k, {required boss}) => switch (sprites.sheet(_keyFor(k, boss: boss))?.frameW) {
          null => null,
          final f => f * (boss ? _boost(k, boss: true) : 1),
        },
      )
      ..step(bakeDensity);
    // poseCount까지만 — 그 뒤는 지난 파의 옛 자리(사용자 버그 '몬스터가 다가오다 전부 멈춘다': 파가 끝나 적이 0이 돼도 옛 적을 그렸다).
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if ((e.layer == 'underwater') != under || e.emerging) continue;
      if (!cull.contains(Offset(e.drawX, e.drawY))) continue;
      final key = (e.boss ? _bossKeys : _enemyKeys)[e.kind] ??= _keyFor(e.kind, boss: e.boss);
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      final hd = key.startsWith('td_e') || key.startsWith('td_b')
          ? hdSheets.sheet(
              e.kind,
              boss: e.boss,
              world: sheet.frameW * _boost(e.kind, boss: e.boss),
              density: bakeDensity,
            )
          : null;
      // 보스는 프레임 300ms·숨쉬기 3%, 큰 보스(대보스 88도트)는 350ms(S1 '대보스 존재감').
      final huge = e.boss && sheet.frameW >= _hugeW;
      final period = huge ? 350 : (e.boss ? 300 : 220);
      final phase = scene.clockMs / period + e.id;
      final frame = phase.floor() % sheet.frames;
      // 모션 v1: 2프레임 깜빡임 대신 프레임 끝 30% 동안 다음 프레임으로 서서히 겹쳐 넘어간다(절전이면 끔).
      final u = phase - phase.floor();
      final blend = !lite && sheet.frames > 1 && u > 0.7 ? (u - 0.7) / 0.3 : 0.0;
      final angry = e.boss && (scene.topHits.traits?.bossFx.enraged(e.id) ?? false); // 분노: 8% 크게
      // 모션 v1 등장: 처음 보인 적은 0.24초 동안 0.3 → 1.12 → 1로 톡 커지며 물 고리(갑자기 나타나지 않게).
      final born = _born.putIfAbsent(e.id, () => clock);
      final bk = (clock - born) / _bornMs;
      final pop = e.boss ? _rise(clock) : _bornPop(bk);
      if (bk == 0 && !lite && !crowd && !e.boss && _rings.length < 24) _rings.add((e.drawX, e.drawY, clock));
      // HD 보스는 그림 안에서 숨쉰다(굽힌 8장).
      final breathe =
          (e.boss ? (hd != null ? 1 : 1 + 0.03 * math.sin(clock / 420 + e.id)) * (angry ? 1.08 : 1) : 1.0) * pop;
      final lunge = _lungeOf(e.id, e.drawX, e.drawY, clock) + scene.topHits.juice.knockOf(e.id, clock);
      final flash = e.boss && hd != null ? _bossFlash(e.id, now: clock, on: e.flash) : e.flash;
      final hot = !flash && hotAt != null && hotAt!(e.drawX, e.drawY);
      final crack = e.boss ? _crack(e, clock) : 1e9; // 보스 체력 층이 깨지면 '부서짐'(조각·1초 비틀·어지러운 눈)
      final tilt = e.boss ? scene.topHits.breaks.tiltOf(e.id, clock) + _crackTilt(crack) : 0.0;
      // HD: 정면 3/4 그림이라 진행 방향으로 돌리지 않고 살짝 흔들기만(좌우는 시트 행으로).
      final rotation = hd != null
          ? math.sin(clock / 240 + e.id) * 0.06 + tilt
          : e.heading + math.pi / 2 + math.sin(clock / 240 + e.id) * 0.08 + tilt;
      final _Spr spr;
      if (hd != null) {
        final f = ((clock + e.id * 37) / (HdKit.loopMs / HdKit.frames)).floor() % HdKit.frames;
        // HD v2 표정: 쓰러짐(브레이크) > 공격 예고(EnemyWindup) > 평소.
        final mood = !hd.moods
            ? (hd.hits && flash ? HdMood.hit : HdMood.idle) // 잡몹 v2: 맞으면 찡긋
            : (scene.topHits.breaks.isDown(e.id, clock) || crack < 600
                  ? HdMood.down
                  : (scene.topHits.muzzle.charging(e.id, clock) ? HdMood.windup : HdMood.idle));
        spr = (image: hd.image, src: hd.src(f, right: _facing(e.id, e.heading), mood: mood), scale: hd.scale, hd: true);
      } else {
        spr = (image: sheet.image, src: _cell(sheet, frame), scale: 1.0, hd: false);
      }
      // 쏘기 직전 빛(EnemyWindup → EnemyFired): HD는 쏘는 부위, 도트는 몸 가운데.
      scene.topHits.muzzle.collect(
        e.id,
        e.kind,
        e.drawX,
        e.drawY,
        hd?.world ?? sheet.frameW,
        right: hd != null && (_right[e.id] ?? false),
        now: clock,
      );
      // 기기 픽셀에 맞춤(모션 v1 — 전장 1단위 ≈ 4px로 반올림해 뚝뚝 떨리던 것).
      final tx = ((e.drawX + math.sin(clock / 160 + e.id * 1.7) * 0.7 + lunge.dx) * snap).roundToDouble() / snap;
      final ty = ((e.drawY + math.cos(clock / 190 + e.id * 2.3) * 0.7 + lunge.dy) * snap).roundToDouble() / snap;
      // 손맛 v4: 막 맞은 적은 찌그러졌다 튐 — 가로·세로 배율이 달라 drawAtlas 대신 하나씩(프레임당 [_maxSquash]마리까지).
      if (!e.boss) _seen[e.id] = (spr, tx, ty, rotation);
      final sq = _squashed.length >= (crowd ? 8 : _maxSquash)
          ? null
          : _soft(scene.topHits.juice.squashOf(e.id, clock), e.boss);
      if (sq != null) {
        _squashed.add((spr, rotation, tx, ty, sq.$1, sq.$2, flash ? (e.boss ? _hdFlash : _tintPaint) : null, hot));
        continue;
      }
      final batch = (flash ? _flashBatches : (hot ? _hotBatches : _batches)).putIfAbsent(
        spr.image,
        () => _Batch(spr.image, flash: flash, boss: e.boss, hd: spr.hd),
      );
      // 헤엄 흔들림(실제 시간): 엔진 히트스톱으로 자리가 멈춘 틱에도 살아 있어 보이게(S1 — 엔진 무관).
      final xf = RSTransform.fromComponents(
        rotation: rotation,
        scale:
            (key == _merchant ? _merchantScale : breathe) *
            spr.scale *
            (hd == null && e.boss ? _boost(e.kind, boss: true) : 1),
        anchorX: spr.src.width / 2,
        anchorY: spr.src.height / 2,
        translateX: tx,
        translateY: ty,
      );
      if (spr.hd) {
        batch.add(xf, spr.src, 1); // HD는 8장이라 섞지 않는다
        continue;
      }
      batch.add(xf, spr.src, 1 - blend * 0.5);
      if (blend > 0) batch.add(xf, _cell(sheet, frame + 1), blend);
    }
    for (final b in _batches.values.followedBy(_flashBatches.values)) {
      if (b.xf.isEmpty) continue;
      // 흰 실루엣은 보스만(강), 보통 명중은 금빛 색 번쩍(사용자 '흰 번쩍임 눈 아프다').
      // HD 보스 맞음은 흰 실루엣 대신 반쯤 흰빛(그림이 보이게).
      final paint = b.flash
          ? (b.boss ? (b.hd ? _hdFlash : _flashPaint) : _tintPaint)
          : (under ? _underPaint : _atlasPaint);
      c.drawAtlas(b.image, b.xf, b.src, b.colors, BlendMode.modulate, null, _q(paint, hd: b.hd));
    }
    for (final b in _hotBatches.values) {
      if (b.xf.isEmpty) continue;
      c.drawAtlas(b.image, b.xf, b.src, b.colors, BlendMode.modulate, null, _q(_hotPaint, hd: b.hd));
    }
    for (final (spr, rot, tx, ty, sx, sy, flash, hot) in _squashed) {
      c
        ..save()
        ..translate(tx, ty)
        ..rotate(rot)
        ..scale(sx, sy);
      _draw(c, spr, flash ?? (hot ? _hotPaint : (under ? _underPaint : _atlasPaint)));
      c.restore();
    }
    _squashed.clear();
    if (!under) scene.topHits.muzzle.paint(c);
    _transitions(c, under: under, clock: clock, lite: lite);
  }

  static const _bornMs = 240.0;
  static const _dieMs = 160.0;
  final Map<int, double> _born = {};
  final List<(double, double, double)> _rings = []; // 등장 물 고리 x, y, ms
  final Map<int, (_Spr, double, double, double)> _seen = {};
  final Map<int, (_Spr, double, double, double)> _lastUnder = {};
  final Map<int, (_Spr, double, double, double)> _lastOver = {};
  final List<(_Spr, double, double, double, double)> _dying = [];

  final hdSheets = HdSheets(); // HD 카툰 시트(개편 ④)
  final Map<int, bool> _right = {};
  final Map<int, double> _bossFlashAt = {};

  /// HD 좌우: 오른쪽으로 가면 뒤집은 행. 거의 위아래로 가면(|cos| < 0.3) 지난 방향 유지(떨림 방지).
  bool _facing(int id, double heading) {
    final x = math.cos(heading);
    return _right[id] = x > 0.3 || (x >= -0.3 && (_right[id] ?? x > 0));
  }

  static Rect _cell(SpriteSheet s, int frame) => Rect.fromLTWH(frame % s.frames * s.frameW, 0, s.frameW, s.frameH);

  Paint _q(Paint p, {required bool hd}) => p..filterQuality = hd ? FilterQuality.medium : FilterQuality.none;

  void _draw(Canvas c, _Spr s, Paint p) {
    final w = s.src.width * s.scale;
    final h = s.src.height * s.scale;
    c.drawImageRect(s.image, s.src, Rect.fromLTWH(-w / 2, -h / 2, w, h), _q(p, hd: s.hd));
  }

  final _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  final List<(_Spr, double, double, double, double, double, Paint?, bool)> _squashed = []; // 맞음 붓(없으면 평소)
  static const _maxSquash = 20;

  final Map<Image, _Batch> _batches = {};
  final Map<Image, _Batch> _flashBatches = {};
  final Map<Image, _Batch> _hotBatches = {};

  /// 피버 녹이기: 이 자리(전장 좌표)의 적은 빨갛게 달아오른다. null이면 없음.
  bool Function(double x, double y)? hotAt;
  final _hotPaint = Paint()
    ..isAntiAlias = false
    ..colorFilter = const ColorFilter.mode(Color(0xFFFF8A50), BlendMode.modulate);
  final Map<String, String> _enemyKeys = {};

  /// 돌발 이벤트 적(황금 물고기·바다뱀·상인선)은 td_event 그림, 나머지는 td_enemy·td_boss.
  String _keyFor(String kind, {required bool boss}) {
    if (sprites.sheet('td_event:$kind') != null) return 'td_event:$kind';
    // HD 그림만 있는 새 보스(순환 v2 18종 — 도트 없음): 크기 기준은 보통 보스 칸을 빌린다(그림은 HD 종 그대로).
    if (boss && sprites.sheet('td_boss:$kind') == null && hdBosses.containsKey(kind)) return 'td_boss:hammer_shark';
    return boss ? 'td_boss:$kind' : 'td_enemy:$kind';
  }

  final Map<String, String> _bossKeys = {};

  /// 전장 1단위당 기기 픽셀(TopScenePainter가 프레임마다) — 위치를 이 격자에 맞춘다.
  double snap = 1;
  double bakeDensity = 1; // HD 굽기 밀도(줌 뺀 단위당 px)
  static const _hugeW = 80;
  final _atlasPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  late final _underPaint = Paint()
    ..isAntiAlias = false
    ..color = const Color.fromRGBO(255, 255, 255, _underwaterAlpha);
  final _tintPaint = Paint()
    ..isAntiAlias = false
    ..colorFilter = const ColorFilter.mode(Color(0x66FFD24A), BlendMode.srcATop);
  final _hdFlash = Paint()..colorFilter = const ColorFilter.mode(Color(0x99FFFFFF), BlendMode.srcATop);
  final _flashPaint = Paint()
    ..isAntiAlias = false
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);
}

/// 같은 그림(종류·번쩍임) 적 묶음 — 프레임마다 비우고 다시 채운다(리스트 재사용).
class _Batch {
  _Batch(this.image, {required this.flash, this.boss = false, this.hd = false});
  final Image image;
  final bool flash;
  final bool boss;
  final bool hd;
  final xf = <RSTransform>[];
  final src = <Rect>[];
  final colors = <Color>[];

  /// [alpha] = 겹침 투명도(프레임 넘김 섞기).
  void add(RSTransform t, Rect r, double alpha) {
    xf.add(t);
    src.add(r);
    colors.add(Color.fromRGBO(255, 255, 255, alpha));
  }

  void clear() {
    xf.clear();
    src.clear();
    colors.clear();
  }
}
