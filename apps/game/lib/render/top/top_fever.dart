import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 탑다운 피버 연출 (사용자 '피버타임 임펙트가 하나도 없다 — 극적인 연출이 있어야 인식한다', S1):
/// 시작 = 배에서 퍼지는 금빛 충격파 고리(번쩍·흔들림은 FunDirector·TopOverlays),
/// 동안 = 바다가 금·주황으로 물듦(적 아래 층이라 가독성 유지)·배 둘레 불꽃 오라·가장자리 속도선(발사체 불 꼬리는 PbFxPainter.fever),
/// 끝 = [_fadeOutMs]에 걸쳐 서서히 원래 색. 번쩍임 끄기·흔들기 끄기(동작 줄이기)·절전을 따른다.
class TopFever {
  TopFever(this.scene);

  final BattleScene scene;
  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke;

  late final JsonReader _cfg = scene.fx.raw.obj('topEvents').obj('fever');
  late final Color _gold = Color(parseArgb(_cfg.str('border'), 'topEvents.fever.border'));
  late final Color _orange = Color(parseArgb(_cfg.str('orange'), 'topEvents.fever.orange'));
  late final double _seaAlpha = _cfg.number('seaAlpha');

  /// 녹이기 오라 반지름(전장 단위) — 엔진 FeverAura(S2)가 오면 그 값, 전에는 fx_map fever.meltRadius.
  double meltRadius = 0;
  late final double _meltDefault = _cfg.number('meltRadius');

  /// 피버 세기 0~1 (켜질 때 [_fadeInMs], 꺼질 때 [_fadeOutMs]).
  double level = 0;
  double _startMs = -1000000000;
  double _lastMs = 0;
  bool _was = false;
  static const _fadeInMs = 300.0;
  static const _fadeOutMs = 1200.0;
  static const _ringMs = 650.0;

  /// 프레임마다 한 번: 세기·시작 시각 갱신.
  void update(double ms) {
    final dt = (ms - _lastMs).clamp(0.0, 100.0);
    _lastMs = ms;
    // 빠른 항해 돌파 동안도 황금 질주(바다·속도선·질주) — S5 fastSail.
    final on = scene.frame.feverTicksLeft > 0 || scene.frame.fastSail != null;
    if (on && !_was) _startMs = ms;
    _was = on;
    level = on ? math.min(1, level + dt / _fadeInMs) : math.max(0, level - dt / _fadeOutMs);
  }

  /// 바다 물들임 세기 0~1 (TopSeaPainter.fever로 — 바다 색 자체를 금·주황으로 섞는다).
  /// 켜질 때는 시작 금빛 번쩍 아래에서 바로 금(파랑+금이 섞이면 탁한 회색·올리브 — S1), 꺼질 때만 서서히.
  double get sea => _seaAlpha * (scene.frame.feverTicksLeft > 0 || scene.frame.fastSail != null ? 1 : level);

  /// 빛 줄기: 비스듬한 밝은 띠 3개가 천천히 흘러간다(빛나는 황금 바다, S1). 배 중심 원점 화면 단위 [view], 적보다 먼저.
  void rays(Canvas c, Rect view) {
    if (level <= 0 || scene.settings.powerSave) return;
    final ms = _lastMs;
    final span = view.width + view.height;
    c
      ..save()
      ..clipRect(view);
    for (var i = 0; i < 3; i++) {
      final x = view.left - view.height + ((ms / (60 + i * 17) + i * span / 3) % span);
      final w = 14.0 + i * 8;
      final pulse = 0.5 + 0.5 * math.sin(ms / 700 + i * 2);
      _ray
        ..reset()
        ..moveTo(x, view.bottom)
        ..lineTo(x + w, view.bottom)
        ..lineTo(x + w + view.height * 0.6, view.top)
        ..lineTo(x + view.height * 0.6, view.top)
        ..close();
      _paint.color = const Color(0xFFFFF6D0).withValues(alpha: (0.10 + 0.08 * pulse) * level);
      c.drawPath(_ray, _paint);
    }
    c.restore();
  }

  final _ray = Path();

  /// 배 둘레 불꽃 오라(배 중심 원점, 배 아래) + 시작 충격파 고리.
  void aura(Canvas c, double shipR) {
    final ms = _lastMs;
    final age = ms - _startMs;
    if (age >= 0 && age < _ringMs) {
      final t = age / _ringMs;
      _ring
        ..strokeWidth = 4 * (1 - t) + 1
        ..color = _gold.withValues(alpha: 0.9 * (1 - t));
      c.drawCircle(Offset.zero, shipR + 130 * _easeOut(t), _ring);
      _ring
        ..strokeWidth = 2
        ..color = _orange.withValues(alpha: 0.7 * (1 - t));
      c.drawCircle(Offset.zero, shipR + 90 * _easeOut(t), _ring);
    }
    if (level <= 0) return;
    // 녹이기 오라: 반지름 R의 빛 원(은은한 주황 + 맥박 금 테).
    final r = meltRadius > 0 ? meltRadius : _meltDefault;
    final pulse = 0.5 + 0.5 * math.sin(ms / 200);
    _paint.color = _orange.withValues(alpha: 0.14 * level);
    c.drawCircle(Offset.zero, r, _paint);
    _ring
      ..strokeWidth = 1.5
      ..color = _gold.withValues(alpha: (0.45 + 0.35 * pulse) * level);
    c.drawCircle(Offset.zero, r, _ring);
    final n = scene.settings.powerSave ? 10 : 20;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + ms / 2400;
      final flick = 0.5 + 0.5 * math.sin(ms / 70 + i * 2.3);
      final r = shipR + 2 + flick * 3;
      final x = (math.cos(a) * r).roundToDouble();
      final y = (math.sin(a) * r * 1.25).roundToDouble();
      final h = 2 + (flick * 3).roundToDouble();
      _paint.color = _orange.withValues(alpha: 0.85 * level);
      c.drawRect(Rect.fromLTWH(x - 1, y - h, 3, h + 1), _paint);
      _paint.color = _gold.withValues(alpha: 0.95 * level);
      c.drawRect(Rect.fromLTWH(x, y - h + 1, 1, h), _paint);
    }
  }

  /// 녹이기 반지름 안인가(전장 좌표 [x],[y], 배 [ship]).
  bool melting(double x, double y, Offset ship) {
    if (level <= 0) return false;
    final r = meltRadius > 0 ? meltRadius : _meltDefault;
    final dx = x - ship.dx;
    final dy = y - ship.dy;
    return dx * dx + dy * dy <= r * r;
  }

  /// 오라에 닿은 적 위 불씨·연기(전장 좌표). 적 그리기 뒤.
  void embers(Canvas c, Offset ship) {
    if (level <= 0 || scene.settings.powerSave) return;
    final ms = _lastMs;
    var drawn = 0;
    for (var k = 0; k < scene.poseCount && drawn < 40; k++) {
      final e = scene.poses[k];
      if (!melting(e.drawX, e.drawY, ship)) continue;
      drawn++;
      for (var j = 0; j < 3; j++) {
        final t = ((ms / 600) + e.id * 0.37 + j / 3) % 1;
        final x = e.drawX + math.sin(e.id * 1.3 + j * 2.1) * 4;
        final y = e.drawY - 2 - t * 9;
        _paint.color = (j == 2 ? const Color(0xFF8A8A92) : (j.isEven ? _orange : _gold)).withValues(
          alpha: (1 - t) * level,
        );
        c.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), j == 2 ? 2 : 1, j == 2 ? 2 : 1), _paint);
      }
    }
  }

  /// 시작 가속 0~1 (0.4초 동안 앞으로 '쑥' 갔다 돌아옴). 흔들기(동작) 끄기면 0.
  double lunge() {
    final age = _lastMs - _startMs;
    if (age < 0 || age >= 400 || !scene.settings.shake) return 0;
    return math.sin(math.pi * age / 400);
  }

  /// 시작 0.6초 폭발 세기 1 → 0 (금빛 잔상·속도선 폭발). 흔들기(동작) 끄기면 0.
  double burst() {
    final age = _lastMs - _startMs;
    if (age < 0 || age >= 600 || !scene.settings.shake) return 0;
    return 1 - age / 600;
  }

  /// 배 둘레 바람 줄(흰 짧은 곡선이 양옆으로 뒤로 흘러감), 배 중심 원점. 흔들기 끄기면 없음.
  void wind(Canvas c, double shipR) {
    if (level <= 0 || !scene.settings.shake) return;
    final ms = _lastMs;
    _ring
      ..strokeWidth = 1
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.65 * level);
    for (var j = 0; j < 6; j++) {
      final side = j.isEven ? 1.0 : -1.0;
      final y = ((ms / 2.2 + j * 37) % 90) - 45;
      final x = side * (shipR + 6 + (j % 3) * 5);
      _wind
        ..reset()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + side * 3, y + 6, x, y + 12);
      c.drawPath(_wind, _ring);
    }
  }

  final _wind = Path();

  /// 양옆으로 휙휙 스치는 물보라 줄·바위·부표(화면 dp). 절전이면 없음.
  void rushers(Canvas c, Size box) {
    if (level <= 0.2 || scene.settings.powerSave) return;
    final ms = _lastMs;
    for (var i = 0; i < 6; i++) {
      final left = i.isEven;
      final x = left ? box.width * (0.06 + i * 0.012) : box.width * (0.94 - i * 0.012);
      final y = (ms * (1.4 + (i % 3) * 0.3) + i * 377) % (box.height + 120) - 60;
      final a = level;
      if (i % 3 == 0) {
        // 바위: 짙은 회색 덩이 + 흰 물보라 테
        _paint.color = const Color(0xFF5E5A60).withValues(alpha: a);
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 14, height: 10), _paint);
        _ring
          ..strokeWidth = 2
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * a);
        c.drawOval(Rect.fromCenter(center: Offset(x, y + 2), width: 20, height: 14), _ring);
      } else if (i % 3 == 1) {
        // 부표: 빨강·흰 원 + 물결 고리
        _paint.color = const Color(0xFFE8443A).withValues(alpha: a);
        c.drawCircle(Offset(x, y), 4, _paint);
        _paint.color = const Color(0xFFFFFFFF).withValues(alpha: a);
        c.drawCircle(Offset(x, y), 1.6, _paint);
        _ring
          ..strokeWidth = 1
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 * a);
        c.drawCircle(Offset(x, y + 1), 7, _ring);
      } else {
        // 물보라 줄
        _paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * a);
        c
          ..drawRect(Rect.fromLTWH(x, y, 3, 34), _paint)
          ..drawRect(Rect.fromLTWH(x + 5, y + 10, 2, 22), _paint);
      }
    }
  }

  final List<(double, double)> _trail = []; // (배 x, 장면 ms)

  /// 피버 S자 항적: 지난 배 x를 흐름 속도로 뒤로 흘려 흰 거품 줄로(전장 좌표 — 카메라 원점 캔버스).
  void weaveTrail(Canvas c, Offset ship, double ms, double flowSpeed) {
    if (_trail.isEmpty || ms - _trail.last.$2 >= 40) _trail.add((ship.dx, ms));
    _trail.removeWhere((p) => ms - p.$2 > 1600);
    if (level <= 0 || _trail.length < 2) return;
    for (var i = 0; i < _trail.length; i++) {
      final (x, at) = _trail[i];
      final age = (ms - at) / 1000;
      final y = ship.dy + 22 + age * flowSpeed;
      final a = (1 - age / 1.6).clamp(0.0, 1.0) * level;
      _paint.color = const Color(0xFFF2FBFF).withValues(alpha: 0.75 * a);
      c
        ..drawRect(Rect.fromLTWH(x - 5, y, 2, 2), _paint)
        ..drawRect(Rect.fromLTWH(x + 3, y, 2, 2), _paint);
      if (i.isEven) c.drawRect(Rect.fromLTWH(x - 1, y + 1, 2, 2), _paint);
    }
  }

  /// 가장자리 속도선(화면 dp 상자 [box]): 양옆에서 아래로 흐르는 금빛 줄. 흔들기(동작) 끄기·절전이면 없음.
  void speedLines(Canvas c, Size box) {
    if (level <= 0 || !scene.settings.shake || scene.settings.powerSave) return;
    final ms = _lastMs;
    // 시작 0.6초는 속도선 폭발(더 많고 진하게).
    final age = ms - _startMs;
    final burst = age >= 0 && age < 600 ? 1 - age / 600 : 0.0;
    final rush = (scene.frame.fastSail?.speed ?? 1) / 8;
    final n = 22 + (18 * burst).round() + (20 * rush).round();
    for (var i = 0; i < n; i++) {
      final left = i.isEven;
      final edge = box.width * (0.04 + (i * 37 % 9) / 100);
      final x = left ? edge : box.width - edge;
      final len = 60.0 + (i * 53 % 70);
      final y = (ms * (1.6 + (i % 4) * 0.35) + i * 211) % (box.height + len) - len;
      final col = i % 3 == 0 ? _orange : (i % 3 == 1 ? _gold : const Color(0xFFFFFFFF));
      _paint.color = col.withValues(alpha: math.min(1, (0.75 + 0.25 * burst) * level));
      c.drawRect(Rect.fromLTWH(x, y, 3, len), _paint);
    }
  }
}

double _easeOut(double t) => 1 - (1 - t) * (1 - t);
