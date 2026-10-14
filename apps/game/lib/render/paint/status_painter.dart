import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 적 상태 표시 (docs/specs/render-status.md): 머리 위 한 줄(기절 별·화상 불꽃·취약 화살표), 감속 물방울.
/// 감속 색조는 몸통을 칠할 때 적용한다([slowedTint]).
class StatusPainter {
  StatusPainter(this.scene);

  final BattleScene scene;
  final _paint = Paint()..isAntiAlias = false;

  /// 아이콘 한 칸 크기(px).
  static const iconPx = 3.0;

  /// HP 바(적 위 3px) 위로 띄우는 간격.
  static const _aboveHpBar = 4.0;

  /// 아이콘 [count]개를 [cx] 가운데 정렬로 [gap] 간격에 놓을 때의 x들.
  static List<double> iconXs(int count, double cx, double gap) => [
    for (var i = 0; i < count; i++) cx + (i - (count - 1) / 2) * gap,
  ];

  /// 적 사각형 위쪽 [enemyTop]에 대한 아이콘 줄의 위쪽 y.
  static double iconTop(double enemyTop) => enemyTop - _aboveHpBar - iconPx;

  JsonReader get _st => scene.fx.status;
  late final double _gap = _st.number('iconGap');
  late final int _tint = parseArgb(_st.str('slowedTint'), 'status.slowedTint');
  late final double _tintAlpha = _st.number('slowedAlpha');
  late final int _drop = parseArgb(_st.str('dropColor'), 'status.dropColor');
  late final double _dropMs = _st.number('dropPeriodMs');
  late final List<int> _burn = [for (final c in _st.strs('burnColors')) parseArgb(c, 'status.burnColors')];
  late final double _burnMs = _st.number('burnBlinkMs');
  late final int _red = parseArgb(_st.str('vulnerableColor'), 'status.vulnerableColor');
  late final int _star = parseArgb(scene.fx.stun.str('color'), 'stun.color');
  late final double _starOrbit = scene.fx.stun.number('orbitPx');
  late final double _starPeriod = scene.fx.stun.number('periodMs');

  /// 감속 색조 (ARGB, 알파 = 섞는 비율). 스프라이트 필터·플레이스홀더 색 섞기에 쓴다.
  int get slowedTint => ((_tintAlpha * 0xFF).round() << 24) | (_tint & 0xFFFFFF);

  /// 플레이스홀더 색 [argb]에 감속 색조를 섞는다.
  int tintColor(int argb) =>
      (Color.lerp(Color(argb), Color(_tint), _tintAlpha)!.toARGB32() & 0xFFFFFF) | (argb & 0xFF000000);

  void _px(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w, h), _paint);
  }

  /// [e]의 상태 표시. [top]·[bottom]은 적 사각형 위·아래 y.
  void paint(Canvas c, EnemyPose e, double top, double bottom) {
    final clock = scene.clockMs;
    if (e.slowed) {
      final fall = (clock % _dropMs) / _dropMs * iconPx;
      _px(c, e.drawX - 2, bottom + fall, 1, 1, _drop);
      _px(c, e.drawX + 2, bottom + (fall + iconPx / 2) % iconPx, 1, 1, _drop);
    }
    final n = (e.stunned ? 1 : 0) + (e.burning ? 1 : 0) + (e.vulnerable ? 1 : 0);
    if (n == 0) return;
    final y = iconTop(top);
    var k = 0;
    double xAt(int i) => e.drawX + (i - (n - 1) / 2) * _gap;
    if (e.stunned) {
      // 기절: 별 2개가 칸 둘레를 돈다.
      final a = clock / _starPeriod * 2 * math.pi;
      final x = xAt(k++);
      for (var s = 0; s < 2; s++) {
        final ang = a + s * math.pi;
        _px(c, x + math.cos(ang) * _starOrbit - 1, y + 1 + math.sin(ang) * _starOrbit / 2, 2, 2, _star);
      }
    }
    if (e.burning) {
      final x = xAt(k++);
      final phase = (clock ~/ _burnMs).isEven ? 0 : 1;
      final blink = scene.settings.flash;
      if (!blink || phase == 0) _px(c, x - 1, y + 1, 2, 2, _burn[0]);
      if (!blink || phase == 1) _px(c, x, y, 2, 2, _burn[1]);
    }
    if (e.vulnerable) {
      final x = xAt(k);
      _px(c, x - 1, y, iconPx, 1, _red);
      _px(c, x, y + 1, 1, 2, _red);
    }
  }
}
