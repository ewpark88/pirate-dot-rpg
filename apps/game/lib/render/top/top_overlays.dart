import 'dart:ui';

import 'package:game_core/game_core.dart' show BigNumFormat;
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/moments.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';
import 'package:pirate_dot/render/top/top_label.dart';
import 'package:pirate_dot/render/top/top_marks.dart' show edgeVignette, vignetteBump;
import 'package:pirate_dot/render/top/top_ship_damage.dart';

/// 탑다운 피버·폭풍 덮개 (지루함 해소 3종): 피버 금화 비(전장 좌표)와 상자 dp 위 시작 번쩍·번개(테두리는 UI).
class TopOverlays {
  TopOverlays(this.scene, this.sprites, this.atmosphere);

  final BattleScene scene;
  final SpriteDraw sprites;
  final TopAtmosphere atmosphere;

  late final JsonReader _fever = scene.fx.raw.obj('topEvents').obj('fever');
  late final Color _feverColor = Color(parseArgb(_fever.str('border'), 'topEvents.fever.border'));

  final _damage = TopShipDamage();

  /// 전장 좌표 덮개(배 위): 피버 금화 비 + 배 피격 파편·위기 연기·불꽃·회복 반짝(침몰 중엔 침몰 연출만). [shipR] = 선체 반폭.
  void world(Canvas c, Rect view, double ms, double shipR, {required bool fever}) {
    if (fever) feverCoins(c, view, ms);
    if (scene.moments.sinkMs > 0) return;
    _damage.paint(
      c,
      scene.topShip,
      shipR * 0.6,
      scene.shipHpRatio,
      ms,
      lite: scene.topHits.lite || scene.settings.powerSave,
    );
  }

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
  int get labels => _label.cached;

  /// 큰 띠(심연의 탑 '12F'·보스 러시): 화면 가운데 보라(마지막 보스면 붉은) 띠가 펼쳐졌다 접히며 큰 글자 + 위 작은 글자.
  void _tower(Canvas c, Size box) {
    final m = scene.moments;
    if (m.bannerMs <= 0) return;
    final t = 1 - m.bannerMs / m.bannerTotal;
    final open = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
    final h = box.height * 0.085 * open;
    final cy = box.height * m.bannerY;
    _flashPaint.shader = Gradient.linear(
      Offset(0, cy - h),
      Offset(0, cy + h),
      m.bannerGold
          ? const [Color(0xEE7A4A08), Color(0xEEE0A020), Color(0xEE7A4A08)]
          : m.bannerHot
          ? const [Color(0xEE5A0A14), Color(0xEEB02A2A), Color(0xEE5A0A14)]
          : const [Color(0xEE2A1450), Color(0xEE5A2A8A), Color(0xEE2A1450)],
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
    final big = m.bannerText.length > 5 ? 0.065 : 0.1; // 긴 글자(BOSS RUSH)는 작게
    _label.draw(c, m.bannerText, Offset(box.width / 2, cy + box.height * 0.01), box.height * big * pop);
    if (m.bannerSub.isNotEmpty) {
      _label.draw(
        c,
        m.bannerSub,
        Offset(box.width / 2, cy - h * 1.25),
        box.height * 0.035,
        color: const Color(0xFF7AFFB0),
      );
    }
  }

  /// 피버 시작 'FEVER!'(S1): 0~0.25초 가운데서 크게 튀어나옴 → 0.55초까지 머묾 → 0.9초까지 위 HUD 띠로 날아가며 작아짐.
  /// 끝 'FEVER END': 위쪽 작게 0.9초.
  void _feverWord(Canvas c, Size box) {
    final now = scene.clockMs;
    final top = scene.hudTopDp ?? scene.fx.raw.obj('topCam').number('hudTopDp');
    final a = now - scene.moments.feverAt;
    if (a >= 0 && a < 900) {
      final mid = Offset(box.width / 2, box.height * 0.42);
      final fly = a < 550 ? 0.0 : (a - 550) / 350;
      final ease = fly * fly;
      final pop = a < 250 ? 0.4 + 0.8 * a / 250 - (a > 180 ? 0.2 * (a - 180) / 70 : 0) : 1.0;
      final at = Offset.lerp(mid, Offset(box.width / 2, top + 10), ease)!;
      _label.draw(c, 'FEVER!', at, (box.height * 0.11 * pop * (1 - 0.6 * ease)).roundToDouble(), alpha: 1 - 0.6 * ease);
    }
    final e = now - scene.moments.feverEndAt;
    if (e >= 0 && e < 900) {
      _label.draw(
        c,
        'FEVER END',
        Offset(box.width / 2, top + box.height * 0.08),
        (box.height * 0.035).roundToDouble(),
        alpha: e < 600 ? 1 : (900 - e) / 300,
        color: const Color(0xFFFFE8B0),
      );
    }
  }

  /// 보스 등장 첫 0.3초 화면 어둡게(30% → 0) — 보스만 빛나게.
  void _entryDim(Canvas c, Size box) {
    final m = scene.moments;
    final age = m.entryTotal - m.entryMs;
    if (m.entryMs <= 0 || age > 300) return;
    _flashPaint.color = Color.fromRGBO(10, 6, 24, 0.3 * (1 - age / 300));
    c.drawRect(Offset.zero & box, _flashPaint);
  }

  /// 보스전 누계 'TOTAL 1.2M': 위 HUD 띠 바로 아래 왼쪽 큰 금 글자, 맞을 때마다 1.15배 팝, 끊기면(1.5초) 0.3초에 사라짐.
  void _bossTotal(Canvas c, Size box) {
    final m = scene.moments;
    final age = scene.clockMs - m.bossTotalAt;
    if (m.bossTotal.isZero || age < 0 || age > Moments.bossTotalGapMs) return;
    final fade = age > Moments.bossTotalGapMs - 300 ? (Moments.bossTotalGapMs - age) / 300 : 1.0;
    final pop = age < 120 ? 1.15 - 0.15 * age / 120 : 1.0;
    final top = scene.hudTopDp ?? scene.fx.raw.obj('topCam').number('hudTopDp');
    final s = box.height * 0.045;
    final y0 = top + 8; // 띠 아래 끝 + 8dp, 'TOTAL'과 숫자가 한 덩어리(S1 z02 — 띠 아래 깔림)
    final x = box.width * 0.2; // 보스(가운데)·보스 체력바와 안 겹치게 왼쪽 위
    _label
      ..draw(c, 'TOTAL', Offset(x, y0 + s * 0.3), s * 0.5, alpha: fade, color: const Color(0xFFFF7A3A))
      ..draw(c, m.bossTotal.format(), Offset(x, y0 + s * 1.15), (s * pop).roundToDouble(), alpha: fade);
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
    _feverWord(c, box);
    // 배 체력 25% 아래: 화면 가장자리 붉은 맥박(가볍게 — 가운데는 비움).
    final red = TopShipDamage.edge(scene.shipHpRatio, ms);
    if (red > 0 && scene.moments.sinkMs <= 0) {
      edgeVignette(c, Offset.zero & box, const Color(0xFFFF2A1E), 0.1 + 0.08 * red);
    }
    _entryDim(c, box);
    _tower(c, box);
    _bossTotal(c, box);
    final l = atmosphere.lightning(ms);
    // 폭풍 번개: 전체 흰 번쩍 대신 옅은 하늘색 가장자리.
    if (l > 0 && flash) edgeVignette(c, Offset.zero & box, const Color(0xFFCFE6FF), 0.22 * l);
  }
}
