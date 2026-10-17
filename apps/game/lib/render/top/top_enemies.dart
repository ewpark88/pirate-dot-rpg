import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

/// 탑다운 적 그리기 (TopScenePainter에서 뺌): 그림별 drawAtlas 묶음, 헤엄 흔들림, 배를 때린 적의 돌진, 돌발 이벤트 그림.
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
    return (sprites.sheet(key)?.frameW ?? 12) / 2;
  }

  /// 적을 그림(종류)별로 묶어 drawAtlas 한 번씩 — 150마리여도 그리기 몇 번(S1 부하: 100~150마리 60fps).
  /// 맞은 적(흰 번쩍임)은 흰 실루엣 묶음으로 따로, 물속은 반투명 붓으로.
  void paint(Canvas c, {required bool under, required Rect cull}) {
    for (final b in _batches.values.followedBy(_flashBatches.values).followedBy(_hotBatches.values)) {
      b.clear();
    }
    final clock = scene.clockMs;
    // poseCount까지만 — 그 뒤는 지난 파의 옛 자리(사용자 버그 '몬스터가 다가오다 전부 멈춘다': 파가 끝나 적이 0이 돼도 옛 적을 그렸다).
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if ((e.layer == 'underwater') != under || e.emerging) continue;
      if (!cull.contains(Offset(e.drawX, e.drawY))) continue;
      final key = (e.boss ? _bossKeys : _enemyKeys)[e.kind] ??= _keyFor(e.kind, boss: e.boss);
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      // 큰 보스(대보스 88도트)는 프레임을 느리게(350ms) 바꾸고 숨쉬듯 3% 커졌다 작아진다(S1 '대보스 존재감').
      final huge = e.boss && sheet.frameW >= _hugeW;
      // 보스는 모두(S1 '23종도 2프레임 차이가 작다') 프레임 300ms·숨쉬기 3%, 큰 보스는 350ms.
      final frame = ((scene.clockMs / (huge ? 350 : (e.boss ? 300 : 220))).floor() + e.id) % sheet.frames;
      final angry = e.boss && (scene.topHits.traits?.bossFx.enraged(e.id) ?? false); // 분노: 8% 크게
      final breathe = e.boss ? (1 + 0.03 * math.sin(clock / 420 + e.id)) * (angry ? 1.08 : 1) : 1.0;
      final lunge = _lungeOf(e.id, e.drawX, e.drawY, clock) + scene.topHits.juice.knockOf(e.id, clock);
      final hot = !e.flash && hotAt != null && hotAt!(e.drawX, e.drawY);
      final rotation =
          e.heading +
          math.pi / 2 +
          math.sin(clock / 240 + e.id) * 0.08 +
          (e.boss ? scene.topHits.breaks.tiltOf(e.id, clock) : 0);
      final tx = (e.drawX + math.sin(clock / 160 + e.id * 1.7) * 0.7 + lunge.dx).roundToDouble();
      final ty = (e.drawY + math.cos(clock / 190 + e.id * 2.3) * 0.7 + lunge.dy).roundToDouble();
      // 손맛 v4: 막 맞은 적은 찌그러졌다 튐 — 가로·세로 배율이 달라 drawAtlas 대신 하나씩(프레임당 [_maxSquash]마리까지).
      final sq = huge || _squashed.length >= _maxSquash ? null : scene.topHits.juice.squashOf(e.id, clock);
      if (sq != null) {
        _squashed.add((sheet, frame, rotation, tx, ty, sq.$1, sq.$2, e.flash, hot));
        continue;
      }
      (e.flash ? _flashBatches : (hot ? _hotBatches : _batches)).putIfAbsent(
          sheet,
          () => _Batch(sheet.image, flash: e.flash, boss: e.boss),
        )
        ..xf.add(
          RSTransform.fromComponents(
            // 헤엄 흔들림(실제 시간): 엔진 히트스톱으로 자리가 멈춘 틱에도 살아 있어 보이게(S1 — 엔진 무관).
            rotation: rotation,
            scale: key == _merchant ? _merchantScale : breathe,
            anchorX: sheet.frameW / 2,
            anchorY: sheet.frameH / 2,
            translateX: tx,
            translateY: ty,
          ),
        )
        ..src.add(Rect.fromLTWH(frame * sheet.frameW, 0, sheet.frameW, sheet.frameH));
    }
    for (final b in _batches.values.followedBy(_flashBatches.values)) {
      if (b.xf.isEmpty) continue;
      // 흰 실루엣은 보스만(강), 보통 명중은 금빛 색 번쩍(사용자 '흰 번쩍임 눈 아프다').
      final paint = b.flash ? (b.boss ? _flashPaint : _tintPaint) : (under ? _underPaint : _atlasPaint);
      c.drawAtlas(b.image, b.xf, b.src, null, null, null, paint);
    }
    for (final b in _hotBatches.values) {
      if (b.xf.isNotEmpty) c.drawAtlas(b.image, b.xf, b.src, null, null, null, _hotPaint);
    }
    for (final (sheet, frame, rot, tx, ty, sx, sy, flash, hot) in _squashed) {
      final w = sheet.frameW;
      final h = sheet.frameH;
      c
        ..save()
        ..translate(tx, ty)
        ..rotate(rot)
        ..scale(sx, sy)
        ..drawImageRect(
          sheet.image,
          Rect.fromLTWH(frame * w, 0, w, h),
          Rect.fromLTWH(-w / 2, -h / 2, w, h),
          flash ? _tintPaint : (hot ? _hotPaint : (under ? _underPaint : _atlasPaint)),
        )
        ..restore();
    }
    _squashed.clear();
  }

  final List<(SpriteSheet, int, double, double, double, double, double, bool, bool)> _squashed = [];
  static const _maxSquash = 20;

  final Map<SpriteSheet, _Batch> _batches = {};
  final Map<SpriteSheet, _Batch> _flashBatches = {};
  final Map<SpriteSheet, _Batch> _hotBatches = {};

  /// 피버 녹이기: 이 자리(전장 좌표)의 적은 빨갛게 달아오른다. null이면 없음.
  bool Function(double x, double y)? hotAt;
  final _hotPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFF8A50), BlendMode.modulate);
  final Map<String, String> _enemyKeys = {};

  /// 돌발 이벤트 적(황금 물고기·바다뱀·상인선)은 td_event 그림, 나머지는 td_enemy·td_boss.
  String _keyFor(String kind, {required bool boss}) {
    if (sprites.sheet('td_event:$kind') != null) return 'td_event:$kind';
    return boss ? 'td_boss:$kind' : 'td_enemy:$kind';
  }

  final Map<String, String> _bossKeys = {};
  static const _hugeW = 80;
  final _atlasPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  late final _underPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..color = const Color.fromRGBO(255, 255, 255, _underwaterAlpha);
  final _tintPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0x66FFD24A), BlendMode.srcATop);
  final _flashPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);
}

/// 같은 그림(종류·번쩍임) 적 묶음 — 프레임마다 비우고 다시 채운다(리스트 재사용).
class _Batch {
  _Batch(this.image, {required this.flash, this.boss = false});
  final Image image;
  final bool flash;
  final bool boss;
  final xf = <RSTransform>[];
  final src = <Rect>[];

  void clear() {
    xf.clear();
    src.clear();
  }
}
