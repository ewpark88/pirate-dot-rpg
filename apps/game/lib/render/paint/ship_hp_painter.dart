import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 내 배 체력 막대 (사용자 지적 '내 체력 같은 건 없나?'): 배 바로 위, 늘 보인다. 값은 fx_map `shipHp`.
/// 초록 → 노랑(50%) → 빨강(20%), 25% 아래면 맥박. 맞으면 테두리가 흰빛으로 번쩍·살짝 흔들리고, 깎인 만큼 흰 조각이 늦게 줄어든다.
/// 회복되면 초록으로 반짝. 비율은 지금 화면 프레임의 shipHp / shipHpMax.
class ShipHpPainter {
  ShipHpPainter(this.scene);

  final BattleScene scene;
  late final JsonReader _cfg = scene.fx.raw.obj('shipHp');
  int _c(String k) => parseArgb(_cfg.str(k), 'shipHp.$k');
  late final int _full = _c('full');
  late final int _mid = _c('mid');
  late final int _low = _c('low');
  late final int _back = _c('back');
  late final int _edge = _c('edge');
  late final int _lagColor = _c('lag');
  late final double _lagMs = _cfg.number('lagMs');
  late final double _healMs = _cfg.number('healMs');
  final _paint = Paint()..isAntiAlias = false;

  double _shown = 1;
  double _lag = 1;
  double _lastClock = 0;
  double _hitMs = 0;
  double _healLeft = 0;

  static const _hitFlashMs = 140.0;

  double get _ratio {
    final f = scene.frame;
    if (f.shipHpMax.isZero) return 1;
    return (f.shipHp / f.shipHpMax).toDouble().clamp(0.0, 1.0);
  }

  int _colorFor(double r) {
    if (r <= 0.2) return _low;
    if (r >= 0.5) return Color.lerp(Color(_mid), Color(_full), ((r - 0.5) / 0.5).clamp(0.0, 1.0))!.toARGB32();
    return Color.lerp(Color(_low), Color(_mid), (r - 0.2) / 0.3)!.toARGB32();
  }

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, w, h), _paint);
  }

  /// [box] = 배 그림 상자 (도트). 막대는 그 위 가운데.
  void paint(Canvas c, Rect box) {
    final dt = (scene.clockMs - _lastClock).clamp(0.0, 100.0);
    _lastClock = scene.clockMs;
    final r = _ratio;
    if (r < _shown - 1e-6) _hitMs = _hitFlashMs;
    if (r > _shown + 1e-6) _healLeft = _healMs;
    _shown = r;
    // 흰 조각: 깎인 뒤 lagMs 동안 천천히 따라 내려온다.
    _lag = _lag < r ? r : math.max(r, _lag - dt / _lagMs);
    if (_hitMs > 0) _hitMs -= dt;
    if (_healLeft > 0) _healLeft -= dt;

    final w = _cfg.number('w');
    final h = _cfg.number('h');
    final shake = _hitMs > 0 ? ((scene.clockMs / 30).floor().isEven ? 1.0 : -1.0) : 0.0;
    final left = (box.center.dx - w / 2 + shake).roundToDouble();
    final top = (box.top - _cfg.number('lift') - h).roundToDouble();
    _fill(c, left - 1, top - 1, w + 2, h + 2, _hitMs > 0 && scene.settings.flash ? 0xFFFFFFFF : _edge);
    _fill(c, left, top, w, h, _back);
    _fill(c, left, top, (w * _lag).roundToDouble(), h, _lagColor);
    var color = _colorFor(r);
    if (r < 0.25 && (scene.clockMs / 250).floor().isEven) {
      color = Color.lerp(Color(color), const Color(0xFFFFFFFF), 0.35)!.toARGB32();
    }
    if (_healLeft > 0) color = Color.lerp(Color(color), const Color(0xFFB8FFB8), _healLeft / _healMs)!.toARGB32();
    _fill(c, left, top, (w * r).roundToDouble(), h, color);
    _fill(c, left, top, (w * r).roundToDouble(), 1, 0x55FFFFFF); // 위 줄 하이라이트
  }
}
