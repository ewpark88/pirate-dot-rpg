import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';

/// 탑다운 피버·폭풍 덮개 (지루함 해소 3종): 피버 금화 비(전장 좌표)와 상자 dp 위 금빛 테두리·시작 번쩍·번개.
class TopOverlays {
  TopOverlays(this.scene, this.sprites, this.atmosphere);

  final BattleScene scene;
  final SpriteDraw sprites;
  final TopAtmosphere atmosphere;

  late final JsonReader _fever = scene.fx.raw.obj('topEvents').obj('fever');
  late final Color _feverColor = Color(parseArgb(_fever.str('border'), 'topEvents.fever.border'));
  final _border = Paint()..style = PaintingStyle.stroke;
  final _overlay = Paint();

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

  /// 상자 dp 위 덮개: 피버 금빛 테두리(맥박)·피버 시작 번쩍·폭풍 번개(번쩍임 설정이 켜졌을 때만).
  void paint(Canvas c, Size box, double ms) {
    final view = scene.frame;
    final flash = scene.settings.flash;
    if (view.feverTicksLeft > 0) {
      final pulse = 0.55 + 0.45 * math.sin(ms / _fever.number('pulseMs') * math.pi);
      final w = _fever.number('borderDp');
      // 안쪽으로 번지는 금빛(넓고 흐림) + 가장자리 금 테(선명)
      _border
        ..strokeWidth = w * 3
        ..color = _feverColor.withValues(alpha: 0.35 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w);
      c.drawRect((Offset.zero & box).deflate(w * 1.5), _border);
      _border
        ..strokeWidth = w
        ..color = _feverColor.withValues(alpha: 0.6 + 0.4 * pulse)
        ..maskFilter = null;
      c.drawRect((Offset.zero & box).deflate(w / 2), _border);
    }
    final f = scene.moments.feverFlashMs;
    if (f > 0 && flash) {
      // 피버 시작 금빛 번쩍(사용자 '임펙트가 없다' — 0.35 → 0.6).
      // 'screen' 섞기: 밝아지며 금빛(덮으면 파랑+금 = 탁한 초록).
      _overlay
        ..color = _feverColor.withValues(alpha: 0.75 * f / _fever.number('flashMs'))
        ..blendMode = BlendMode.screen;
      c.drawRect(Offset.zero & box, _overlay);
      _overlay.blendMode = BlendMode.srcOver;
    }
    final l = atmosphere.lightning(ms);
    if (l > 0 && flash) {
      _overlay.color = Color.fromRGBO(240, 246, 255, 0.45 * l);
      c.drawRect(Offset.zero & box, _overlay);
    }
  }
}
