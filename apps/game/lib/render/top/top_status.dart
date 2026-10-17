import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/hd/hd_status_marks.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 탑다운 적 상태 아이콘 (S1 '무리 속 색종이' → 읽히게): 5×5 도트 + 남색 테두리 1, 적 위 한 줄.
/// 기절 별(반짝) · 화상 불꽃(일렁) · 감속 눈송이 · 취약 깨진 방패. 색은 fx_map status·stun(옆모습과 같은 팔레트).
class TopStatus {
  TopStatus(this.scene);

  final BattleScene scene;
  final _paint = Paint()..isAntiAlias = false;

  JsonReader get _st => scene.fx.status;
  late final int _star = parseArgb(scene.fx.stun.str('color'), 'stun.color');
  late final List<int> _burn = [for (final c in _st.strs('burnColors')) parseArgb(c, 'status.burnColors')];
  late final int _ice = parseArgb(_st.str('dropColor'), 'status.dropColor');
  late final int _red = parseArgb(_st.str('vulnerableColor'), 'status.vulnerableColor');
  static const _edge = 0xFF1B2A4A;
  static const _white = 0xFFFFFFFF;

  /// 아이콘 한 칸(테두리 포함 7)과 간격.
  static const _step = 7.0;

  // 글자: x = 주색, o = 보조색(밝은 점), . = 빈칸.
  static const _starA = ['..x..', '.xox.', 'xxoxx', '.xxx.', 'x...x'];
  static const _starB = ['..x..', '.xxx.', 'xxoxx', '.xox.', 'x...x'];
  static const _flameA = ['..x..', '.xx..', '.xox.', 'xooox', '.xxx.'];
  static const _flameB = ['...x.', '..xx.', '.xox.', 'xooox', '.xxx.'];
  static const _snow = ['x.x.x', '.xox.', 'xooox', '.xox.', 'x.x.x'];
  static const _shield = ['xx.xx', 'xo.ox', 'xo.ox', '.x.x.', '..x..'];

  /// [e] 위(그림 반지름 [r])에 아이콘 줄.
  void paint(Canvas c, EnemyPose e, double r) {
    final n = (e.stunned ? 1 : 0) + (e.burning ? 1 : 0) + (e.slowed ? 1 : 0) + (e.vulnerable ? 1 : 0);
    if (n == 0) return;
    final clock = scene.clockMs;
    // HD 특성 표식(화상 꽃잎·감속 수정·취약 방울) — 절전이면 아이콘만.
    if (!scene.topHits.lite && (e.burning || e.slowed || e.vulnerable)) {
      _hd.paint(
        c,
        Offset(e.drawX, e.drawY),
        r,
        clock,
        e.id,
        burning: e.burning,
        slowed: e.slowed,
        vulnerable: e.vulnerable,
      );
    }
    final blink = scene.settings.flash;
    final odd = blink && (clock / 180).floor().isOdd;
    final top = (e.drawY - r - 7).roundToDouble();
    var x = (e.drawX - n * _step / 2 + 1).roundToDouble();
    void icon(List<String> rows, int main, int light) {
      _glyph(c, x, top, rows, main, light);
      x += _step;
    }

    if (e.stunned) icon(odd ? _starB : _starA, _star, _white);
    if (e.burning) icon(odd ? _flameB : _flameA, _burn[0], _burn[1]);
    if (e.slowed) icon(_snow, _ice, _white);
    if (e.vulnerable) icon(_shield, _red, 0xFFFFB0A8);
  }

  final _hd = HdStatusMarks();

  // 글자 그림 캐시(모양·색마다 한 번) — 무리 속 아이콘이 많아도 drawPicture 한 번씩(S1 성능 '모두 신화' 버벅임).
  final Map<String, Picture> _cache = {};

  void _glyph(Canvas c, double l, double t, List<String> rows, int main, int light) {
    final key = '${identityHashCode(rows)}|$main|$light';
    final pic = _cache[key] ??= _record(rows, main, light);
    c
      ..save()
      ..translate(l, t)
      ..drawPicture(pic)
      ..restore();
  }

  Picture _record(List<String> rows, int main, int light) {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    for (var y = -1; y <= 5; y++) {
      for (var x = -1; x <= 5; x++) {
        final ch = y >= 0 && y < 5 && x >= 0 && x < 5 ? rows[y][x] : '.';
        if (ch != '.') {
          _px(c, x.toDouble(), y.toDouble(), ch == 'o' ? light : main);
        } else if (_near(rows, x, y)) {
          _px(c, x.toDouble(), y.toDouble(), _edge);
        }
      }
    }
    return rec.endRecording();
  }

  static bool _near(List<String> rows, int x, int y) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx;
      final ny = y + dy;
      if (ny >= 0 && ny < 5 && nx >= 0 && nx < 5 && rows[ny][nx] != '.') return true;
    }
    return false;
  }

  void _px(Canvas c, double l, double t, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, 1, 1), _paint);
  }
}
