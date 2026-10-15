import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/bolt.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/slot_states.dart';

/// 새 스킨 r1(파스텔·통통 버튼·PB 카드, 사용자 승인 — S4 docs/specs/ui-skin-r1.md)의 선원 줄. 값은 fx_map `slotSkin`(dp).
/// - 줄: 크림 바탕, 위 경계선 대신 위로 부드러운 그림자.
/// - 칸: 반지름 12dp, 등급 색 테두리 3dp, 안쪽 = 등급 색 세로 그라데이션(위 흰 55% 섞음 → 아래 15%), 안쪽 흰 1.5dp(60%) 하이라이트,
///   아래 그림자. PB 얼굴 초상(`portrait:<id>`)을 둥글게 잘라 넣는다. 빈 칸은 연한 바탕 + 회청 테두리(가운데 +는 UI).
/// - 궁극기: 금 그라데이션 통통 버튼(아래 4dp 진한 테두리), 반지름 14dp, 게이지 #FF5A6E, 가득 차면 흰·금 깜빡임.
/// 줄 좌표(줄 도트)로 그린다 — 부르는 쪽이 bandOrigin·bandScale로 옮겨 둔다. PB 초상이 없으면 false(도트 칸으로).
class SlotSkinPainter {
  SlotSkinPainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;

  late final JsonReader _cfg = scene.fx.raw.obj('slotSkin');
  int _c(String k) => parseArgb(_cfg.str(k), 'slotSkin.$k');
  late final int _bar = _c('bar');
  late final int _shadowRgb = _c('shadow') & 0xFFFFFF;
  late final int _open = _c('open');
  late final int _openBorder = _c('openBorder');
  late final int _openPlus = _c('openPlus');
  late final int _locked = _c('locked');
  late final int _lockedBorder = _c('lockedBorder');
  late final int _lock = _c('lock');
  late final int _ultTop = _c('ultimateTop');
  late final int _ultBottom = _c('ultimateBottom');
  late final int _ultEdge = _c('ultimateEdge');
  late final int _gauge = _c('gauge');
  late final int _gaugeBack = _c('gaugeBack');
  late final List<int> _rarity = [for (final c in _cfg.strs('rarity')) parseArgb(c, 'slotSkin.rarity')];
  late final Map<String, int> _familyColor = {
    for (final e in scene.fx.familyColors.raw.entries) e.key: parseArgb(e.value as String, 'familyColors.${e.key}'),
  };
  late final Map<String, String> _family = {for (final c in scene.tables.crews.crews) c.id: c.family};

  final _paint = Paint()..isAntiAlias = true;
  final _blur = Paint()..isAntiAlias = true;
  final Map<int, Shader> _shaders = {};
  BattleFrame? _shaderFrame;

  /// dp → 줄 도트.
  double _dp(String k) => _cfg.number(k) / (scene.layout.kb / scene.layout.dpr);
  double _px(double dp) => dp / (scene.layout.kb / scene.layout.dpr);

  bool get ready {
    final fleet = scene.frame.fleet;
    final id = fleet.isEmpty ? scene.tables.crews.crews.first.id : fleet.first.crewId;
    return sprites.sheet('portrait:$id') != null;
  }

  static int _mix(int a, int b, double t) {
    int ch(int s) => (((a >> s) & 0xFF) + ((((b >> s) & 0xFF) - ((a >> s) & 0xFF)) * t)).round();
    return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  /// 칸·버튼 그라데이션 셰이더 (칸 자리·색이 같으면 다시 쓴다 — 프레임당 할당 없음).
  Shader _gradient(int key, Rect r, int top, int bottom) {
    if (!identical(_shaderFrame, scene.layout)) {
      _shaders.clear();
      _shaderFrame = scene.layout;
    }
    return _shaders[key ^ top ^ (bottom << 1)] ??= Gradient.linear(r.topCenter, r.bottomCenter, [
      Color(top),
      Color(bottom),
    ]);
  }

  void _shadow(Canvas c, RRect rr, double blurDp, double dyDp) {
    _blur
      ..color = Color((0x2E << 24) | _shadowRgb)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _px(blurDp) / 2);
    c.drawRRect(rr.shift(Offset(0, _px(dyDp))), _blur);
  }

  /// 칸 하나(등급 색): 그림자 → 테두리 → 그라데이션 판 → 흰 하이라이트. 안쪽 둥근 사각을 돌려준다.
  RRect _slot(Canvas c, int i, Rect r, int rarity) {
    final radius = _dp('radius');
    final border = _dp('border');
    final outer = RRect.fromRectAndRadius(r, Radius.circular(radius));
    _shadow(c, outer, 6, 2);
    _paint
      ..shader = null
      ..color = Color(rarity);
    c.drawRRect(outer, _paint);
    final inner = RRect.fromRectAndRadius(r.deflate(border), Radius.circular(radius - border));
    _paint.shader = _gradient(i, inner.outerRect, _mix(rarity, 0xFFFFFFFF, 0.55), _mix(rarity, 0xFFFFFFFF, 0.15));
    c.drawRRect(inner, _paint);
    _paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = _px(1.5)
      ..color = const Color(0x99FFFFFF);
    c.drawRRect(inner.deflate(_px(0.75)), _paint);
    _paint.style = PaintingStyle.fill;
    return inner;
  }

  void _portrait(Canvas c, RRect inner, String crewId) {
    c
      ..save()
      ..clipRRect(inner);
    final side = inner.outerRect.width * 1.08;
    sprites.drawSmooth(c, 'portrait:$crewId', inner.center.dx, inner.top + side * 0.46, side, side);
    c.restore();
  }

  void _dim(Canvas c, RRect inner, double fraction) {
    c
      ..save()
      ..clipRRect(inner);
    _paint.color = const Color(0x8A1A1630);
    final r = inner.outerRect;
    c
      ..drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * fraction), _paint)
      ..restore();
  }

  /// 선원 줄 전체(줄 좌표). PB 초상이 없으면 false.
  bool paint(Canvas c) {
    if (!ready) return false;
    final layout = scene.layout;
    // 줄 위로 부드러운 그림자(경계선 대신), 그 아래 크림 바탕.
    _blur
      ..color = Color((0x2E << 24) | _shadowRgb)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _px(10) / 2);
    c.drawRect(Rect.fromLTWH(0, -_px(2), layout.bandWidth + 1, layout.bandHeight), _blur);
    _paint
      ..shader = null
      ..color = Color(_bar);
    c.drawRect(Rect.fromLTWH(0, 0, layout.bandWidth + 1, layout.bandHeight + 1), _paint);
    final fleet = scene.frame.fleet;
    for (var i = 0; i < kSlotCount; i++) {
      final r = layout.slotRectInBand(i);
      switch (slotStateAt(scene.tables, scene.frame, i)) {
        case SlotState.open:
          _openSlot(c, r);
          continue;
        case SlotState.locked:
          _lockedSlot(c, r);
          continue;
        case SlotState.crew:
      }
      final slot = fleet[i];
      final flash = scene.slotFlashMs[i] > 0;
      final inner = _slot(c, i, r, flash ? 0xFFFFFFFF : _rarity[slot.rarity.clamp(0, _rarity.length - 1)]);
      _portrait(c, inner, slot.crewId);
      final rem = slot.cooldown.clamp(0.0, 1.0);
      if (rem > 0.02) _dim(c, inner, rem);
      final skill = slot.skillCooldown.clamp(0.0, 1.0);
      final ir = inner.outerRect;
      if (skill > 0) {
        _paint.color = Color(_ultBottom);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(ir.left + _px(3), ir.bottom - _px(4), (ir.width - _px(6)) * (1 - skill), _px(2.5)),
            Radius.circular(_px(1.25)),
          ),
          _paint,
        );
      }
      _paint.color = Color(_familyColor[_family[slot.crewId]] ?? 0xFFFFFFFF);
      c.drawCircle(Offset(ir.left + _px(5), ir.top + _px(5)), _px(3), _paint);
    }
    _ultimate(c, layout.ultimateInBand);
    return true;
  }

  /// 비었지만 열림: 밝은 바탕 + 하늘색 점선 테두리 + 가운데 '+'가 살짝 맥박(누르라는 느낌).
  void _openSlot(Canvas c, Rect r) {
    final t = (scene.clockMs % _cfg.number('openPulseMs')) / _cfg.number('openPulseMs');
    final pulse = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(_dp('radius')));
    _paint
      ..shader = null
      ..color = Color(_open);
    c.drawRRect(rr, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = _px(2.5)
      ..strokeCap = StrokeCap.round
      ..color = Color(_openBorder).withValues(alpha: 0.65 + 0.35 * pulse);
    c.drawPath(_dashes[r] ??= _dashed(rr.deflate(_px(1.5)), _px(6)), _paint);
    final arm = r.width * (0.16 + 0.03 * pulse);
    _paint
      ..strokeWidth = _px(4)
      ..color = Color(_openPlus);
    c
      ..drawLine(r.center.translate(-arm, 0), r.center.translate(arm, 0), _paint)
      ..drawLine(r.center.translate(0, -arm), r.center.translate(0, arm), _paint);
    _paint
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  final Map<Rect, Path> _dashes = {};

  static Path _dashed(RRect rr, double dash) {
    final out = Path();
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash * 2) {
        out.addPath(m.extractPath(d, d + dash), Offset.zero);
      }
    }
    return out;
  }

  /// 잠김(배 등급 부족): 어두운 판 + 자물쇠. '스테이지 N에서 열림' 글자는 UI(S4)가 얹는다(번역).
  void _lockedSlot(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(_dp('radius')));
    _paint
      ..shader = null
      ..color = Color(_lockedBorder);
    c.drawRRect(rr, _paint);
    _paint.color = Color(_locked);
    c.drawRRect(rr.deflate(_px(2)), _paint);
    final u = r.width / 20; // 자물쇠 단위
    final cx = r.center.dx;
    final top = r.top + r.height * 0.24;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 1.6
      ..color = Color(_lock);
    c
      ..drawArc(Rect.fromLTWH(cx - u * 3.2, top, u * 6.4, u * 7), math.pi, math.pi, false, _paint)
      ..drawLine(Offset(cx - u * 3.2, top + u * 3.5), Offset(cx - u * 3.2, top + u * 5), _paint)
      ..drawLine(Offset(cx + u * 3.2, top + u * 3.5), Offset(cx + u * 3.2, top + u * 5), _paint);
    _paint.style = PaintingStyle.fill;
    final body = Rect.fromLTWH(cx - u * 5, top + u * 5, u * 10, u * 7.5);
    c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(u * 1.5)), _paint);
    _paint.color = Color(_locked);
    c
      ..drawCircle(Offset(cx, body.top + u * 3), u * 1.2, _paint)
      ..drawRect(Rect.fromLTWH(cx - u * 0.5, body.top + u * 3, u, u * 2.6), _paint);
  }

  static const _blinkMs = 250.0;

  /// 궁극기 통통 버튼: 아래 4dp 진한 테두리 → 금 그라데이션 몸 → 선장 초상 → 덮개·게이지 → 번개.
  void _ultimate(Canvas c, Rect r) {
    final f = scene.frame;
    final rage = f.rage.clamp(0.0, 1.0);
    final full = rage >= 1;
    final blink = full && (scene.clockMs / _blinkMs).floor().isEven;
    // 뜬 배치는 둥근 큰 버튼(사용자 결정), 예전 배치는 둥근 사각.
    final radius = scene.layout.floating ? r.width / 2 : _dp('ultimateRadius');
    final edge = _px(4);
    final body = Rect.fromLTRB(r.left, r.top, r.right, r.bottom - edge);
    final outer = RRect.fromRectAndRadius(r, Radius.circular(radius));
    _shadow(c, outer, 6, 2);
    _paint
      ..shader = null
      ..color = Color(_ultEdge);
    c.drawRRect(outer, _paint);
    final bodyRR = RRect.fromRectAndRadius(body, Radius.circular(radius));
    _paint.shader = _gradient(99, body, blink ? 0xFFFFFFFF : _ultTop, _ultBottom);
    c.drawRRect(bodyRR, _paint);
    _paint.shader = null;
    final inner = RRect.fromRectAndRadius(body.deflate(_px(4)), Radius.circular(radius - _px(4)));
    final captain = f.captainId;
    if (captain != null) _portrait(c, inner, captain);
    if (!full) _dim(c, inner, 1 - rage);
    final ir = inner.outerRect;
    final g = RRect.fromRectAndRadius(
      Rect.fromLTWH(ir.left + _px(3), ir.bottom - _px(6), ir.width - _px(6), _px(3.5)),
      Radius.circular(_px(1.75)),
    );
    _paint.color = Color(_gaugeBack);
    c.drawRRect(g, _paint);
    if (rage > 0) {
      final gr = g.outerRect;
      _paint.color = Color(full ? (blink ? 0xFFFFFFFF : _ultTop) : _gauge);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(gr.left, gr.top, gr.width * rage, gr.height), g.tlRadius),
        _paint,
      );
    }
    drawBolt(c, _paint, ir.left + _px(3), ir.top + _px(3), _px(1), _ultTop, _ultEdge);
  }
}
