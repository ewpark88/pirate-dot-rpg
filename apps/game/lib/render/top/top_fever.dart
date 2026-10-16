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

  /// 가장자리 속도선(화면 dp 상자 [box]): 양옆에서 아래로 흐르는 금빛 줄. 흔들기(동작) 끄기·절전이면 없음.
  void speedLines(Canvas c, Size box) {
    if (level <= 0 || !scene.settings.shake || scene.settings.powerSave) return;
    final ms = _lastMs;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final left = i.isEven;
      final edge = box.width * (0.04 + (i * 37 % 9) / 100);
      final x = left ? edge : box.width - edge;
      final len = 40.0 + (i * 53 % 50);
      final y = (ms * (0.9 + (i % 4) * 0.25) + i * 211) % (box.height + len) - len;
      _paint.color = (i % 3 == 0 ? _orange : _gold).withValues(alpha: 0.75 * level);
      c.drawRect(Rect.fromLTWH(x, y, 3, len), _paint);
    }
  }
}

double _easeOut(double t) => 1 - (1 - t) * (1 - t);
