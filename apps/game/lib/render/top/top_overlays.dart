import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/moments.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';
import 'package:pirate_dot/render/top/top_label.dart';
import 'package:pirate_dot/render/top/top_marks.dart' show edgeVignette, vignetteBump;

/// 탑다운 피버·폭풍 덮개 (지루함 해소 3종): 피버 금화 비(전장 좌표)와 상자 dp 위 시작 번쩍·번개(테두리는 UI).
class TopOverlays {
  TopOverlays(this.scene, this.sprites, this.atmosphere);

  final BattleScene scene;
  final SpriteDraw sprites;
  final TopAtmosphere atmosphere;

  late final JsonReader _fever = scene.fx.raw.obj('topEvents').obj('fever');
  late final Color _feverColor = Color(parseArgb(_fever.str('border'), 'topEvents.fever.border'));

  /// 피버 금화 비: 보이는 영역 위에서 결정론적 자리로 떨어지며 회전(절전이면 반).
  void feverCoins(Canvas c, Rect view, double ms) {
    final n = (_fever.integer('coins') * (scene.settings.powerSave ? 0.5 : 1)).round();
    const size = 9.0;
    for (var i = 0; i < n; i++) {
      final x = view.left + (i * 53 + 17) % view.width.toInt();
      final y = view.top + ((ms / (14 + i % 5)) + i * 41) % (view.height + 20) - 10;
      sprites.drawSmoothFrame(c, 'coin_hd', ((ms / 70).floor() + i) % 4, x, y, size, size);
    }
  }

  final _flashPaint = Paint();
  final _label = TopLabel();

  /// 심연의 탑 층 띠: 화면 가운데 보라 띠가 펼쳐졌다 접히며 큰 '12F'(클리어면 위에 작은 CLEAR!).
  void _tower(Canvas c, Size box) {
    final m = scene.moments;
    if (m.towerMs <= 0) return;
    final t = 1 - m.towerMs / Moments.towerShowMs;
    final open = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
    final h = box.height * 0.085 * open;
    final cy = box.height * 0.36;
    _flashPaint.shader = Gradient.linear(
      Offset(0, cy - h),
      Offset(0, cy + h),
      const [
        Color(0xEE2A1450),
        Color(0xEE5A2A8A),
        Color(0xEE2A1450),
      ],
      const [0, 0.5, 1],
    );
    c.drawRect(Rect.fromLTRB(0, cy - h, box.width, cy + h), _flashPaint);
    _flashPaint.shader = null;
    _flashPaint.color = const Color(0xFFFFD45A).withValues(alpha: open);
    c
      ..drawRect(Rect.fromLTRB(0, cy - h, box.width, cy - h + 2), _flashPaint)
      ..drawRect(Rect.fromLTRB(0, cy + h - 2, box.width, cy + h), _flashPaint);
    if (open < 0.6) return;
    final pop = t < 0.25 ? 0.6 + 0.4 * (t - 0.15) / 0.1 : 1.0;
    _label.draw(c, '${m.towerFloor}F', Offset(box.width / 2, cy + box.height * 0.01), box.height * 0.1 * pop);
    if (m.towerClear) {
      _label.draw(c, 'CLEAR!', Offset(box.width / 2, cy - h * 1.25), box.height * 0.035, color: const Color(0xFF7AFFB0));
    }
  }

  /// 상자 dp 위 덮개: 피버 금빛 테두리(맥박)·피버 시작 번쩍·폭풍 번개(번쩍임 설정이 켜졌을 때만).
  void paint(Canvas c, Size box, double ms) {
    final flash = scene.settings.flash;
    // 피버 금빛 테두리는 UI(S4 가장자리 불꽃 빛)가 맡는다 — 겹치지 않게 여기서는 안 그린다.
    final f = scene.moments.feverFlashMs;
    // 피버 시작: 전체 금빛 번쩍 대신 가장자리 금빛 비네트(사용자 '흰 번쩍임 눈 아프다').
    if (f > 0 && flash) {
      final bump = vignetteBump(1 - f / _fever.number('flashMs'));
      // 피버 v2: 화면 전체 금빛(밝기 변화 회귀 테스트 안 — 서서히 차오르고 빠짐, 최대 22%) + 가장자리 금빛.
      _flashPaint.color = _feverColor.withValues(alpha: 0.22 * bump);
      c.drawRect(Offset.zero & box, _flashPaint);
      edgeVignette(c, Offset.zero & box, _feverColor, 0.35 * bump);
    }
    _tower(c, box);
    final l = atmosphere.lightning(ms);
    // 폭풍 번개: 전체 흰 번쩍 대신 옅은 하늘색 가장자리.
    if (l > 0 && flash) edgeVignette(c, Offset.zero & box, const Color(0xFFCFE6FF), 0.22 * l);
  }
}
