import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/hp_pill.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 내 배 체력 막대 (사용자 지적 '내 체력 같은 건 없나?'): 배 바로 위, 늘 보인다. 값은 fx_map `shipHp`.
/// 둥근 알약형([HpPill]) — 3단계 색(40% 미만 노랑·15% 미만 빨강, 빨강일 때만 맥박). 맞으면 테두리가 흰빛으로 번쩍·살짝 흔들리고, 깎인 만큼 흰 조각이 늦게 줄어든다.
/// 회복되면 초록으로 반짝. 비율은 지금 화면 프레임의 shipHp / shipHpMax.
class ShipHpPainter {
  ShipHpPainter(this.scene);

  final BattleScene scene;
  late final JsonReader _cfg = scene.fx.raw.obj('shipHp');
  late final HpPill pill = HpPill(_cfg);
  late final double _lagMs = _cfg.number('lagMs');
  late final double _healMs = _cfg.number('healMs');

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

    // 폭은 배 폭과 비슷하게(배 크기 13% — 아이콘 6 포함), 높이 6.
    final w = (box.width * 0.9).clamp(24.0, _cfg.number('w')).roundToDouble() + 6;
    final h = _cfg.number('h');
    final shake = _hitMs > 0 ? ((scene.clockMs / 30).floor().isEven ? 1.0 : -1.0) : 0.0;
    final left = (box.center.dx - w / 2 + shake).roundToDouble();
    final top = (box.top - _cfg.number('lift') - h).roundToDouble();
    var color = pill.colorFor(r);
    if (pill.isLow(r) && (scene.clockMs / 250).floor().isEven) {
      color = Color.lerp(Color(color), const Color(0xFFFFFFFF), 0.35)!.toARGB32();
    }
    if (_healLeft > 0) color = Color.lerp(Color(color), const Color(0xFFB8FFB8), _healLeft / _healMs)!.toARGB32();
    pill.paint(
      c,
      left: left,
      top: top,
      w: w,
      h: h,
      ratio: r,
      lag: _lag,
      fill: color,
      edge: _hitMs > 0 && scene.settings.flash ? 0xFFFFFFFF : null,
    );
  }
}
