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
    final on = scene.frame.feverTicksLeft > 0;
    if (on && !_was) _startMs = ms;
    _was = on;
    level = on ? math.min(1, level + dt / _fadeInMs) : math.max(0, level - dt / _fadeOutMs);
  }

  /// 바다 물들임 세기 0~1 (TopSeaPainter.fever로 — 바다 색 자체를 금·주황으로 섞는다).
  double get sea => _seaAlpha * level;

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

  /// 가장자리 속도선(화면 dp 상자 [box]): 양옆에서 아래로 흐르는 금빛 줄. 흔들기(동작) 끄기·절전이면 없음.
  void speedLines(Canvas c, Size box) {
    if (level <= 0 || !scene.settings.shake || scene.settings.powerSave) return;
    final ms = _lastMs;
    const n = 22;
    for (var i = 0; i < n; i++) {
      final left = i.isEven;
      final edge = box.width * (0.04 + (i * 37 % 9) / 100);
      final x = left ? edge : box.width - edge;
      final len = 60.0 + (i * 53 % 70);
      final y = (ms * (1.6 + (i % 4) * 0.35) + i * 211) % (box.height + len) - len;
      _paint.color = (i % 3 == 0 ? _orange : _gold).withValues(alpha: 0.75 * level);
      c.drawRect(Rect.fromLTWH(x, y, 3, len), _paint);
    }
  }
}

double _easeOut(double t) => 1 - (1 - t) * (1 - t);
