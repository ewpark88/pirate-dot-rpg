import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';

part 'hd_ship_parts.dart';

/// 플레이어 배 색(기본 = 등급색, 스킨 = fx_map topShip.skinPreview의 hull·sail·flag 첫 색들).
typedef HdShipColors = ({Color rim, Color rimD, Color deck, Color deckD, Color sail, Color sailD, Color flag});

/// HD 카툰 플레이어 배(디자인 개편 ④, 사용자 결정 'HD로 전부'): 위에서 본 배 — 전장에서 진행 방향으로 돌아야 해서
/// 정면 3/4(보스 배)가 아니라 위에서 본 모습을 같은 결(굵은 외곽선·위밝음/아래어둠·광택·채도)로 그린다.
/// 매 프레임 코드 벡터로 직접 그린다(배는 하나 — 반동·돛 부풂·부위 빛을 그대로). 배 기준 좌표(가운데 0,0, 뱃머리 위, 단위),
/// 칸 size = 지금 도트 배 칸(맞는 자리·체력 막대 위치 그대로). 부위 단계 = shipLook(hull 7·cannon 7·cargo 7·sail 5·crowsnest 6).
class HdShip {
  final _k = HdKit();
  final _layer = Paint();

  static const HdShipColors _wood = (
    rim: Color(0xFFB0683A),
    rimD: Color(0xFF6A3418),
    deck: Color(0xFFF0C888),
    deckD: Color(0xFFC89458),
    sail: Color(0xFFFFFCF0),
    sailD: Color(0xFFD8CCB4),
    flag: Color(0xFFE8403A),
  );

  /// 등급 기본색: 유령 등급은 청록 반투명 결, 군함은 짙은 나무·빨간 줄 돛.
  static HdShipColors tierColors(String tierId) => switch (tierId) {
    'warship' => (
      rim: const Color(0xFF8A4A2A),
      rimD: const Color(0xFF3E1C0E),
      deck: const Color(0xFFE0B478),
      deckD: const Color(0xFFA87A48),
      sail: const Color(0xFFFFF4E4),
      sailD: const Color(0xFFE09A8A),
      flag: const Color(0xFF2A2A3A),
    ),
    'ghost' => (
      rim: const Color(0xFF5AA8A0),
      rimD: const Color(0xFF1E4A50),
      deck: const Color(0xFFA8E0D4),
      deckD: const Color(0xFF6AA8A0),
      sail: const Color(0xFFE8FFF8),
      sailD: const Color(0xFF9AD8CC),
      flag: const Color(0xFF8AF0C8),
    ),
    _ => _wood,
  };

  /// 스킨 색(fx_map topShip.skinPreview — 운영자 미리보기·계약 전 임시 자리). [load]가 한 번 채운다.
  static final Map<String, HdShipColors> skins = {};
  static final Set<String> rainbowSkins = {};

  /// skinPreview의 hull[0·1·2·4]·sail[0·1]·flag[0]을 HD 색으로(여러 번 불러도 한 번만).
  static void load(JsonReader preview) {
    if (skins.isNotEmpty) return;
    Color at(List<String> l, int i) => Color(parseArgb(l[i.clamp(0, l.length - 1)], 'skin'));
    for (final id in preview.raw.keys) {
      final cfg = preview.obj(id);
      if (!cfg.has('hull') || !cfg.has('sail')) continue;
      final h = cfg.strs('hull');
      final sl = cfg.strs('sail');
      final f = cfg.has('flag') ? cfg.strs('flag') : const ['#E8403A'];
      skins[id] = (
        rim: at(h, 0),
        rimD: at(h, 1),
        deck: at(h, 2),
        deckD: at(h, 4),
        sail: at(sl, 0),
        sailD: at(sl, 1),
        flag: at(f, 0),
      );
      if (cfg.raw['rainbowSail'] == true) rainbowSkins.add(id);
    }
  }

  /// 배를 그린다. [glowPart]·[glow] = 바뀐 부위 흰빛(축하), [recoil] = 대포 반동, [billow] = 돛 부풂, [flash] = 맞음 흰빛,
  /// [alpha] = 반투명(유령선 스킨), [rainbow] = 무지개 돛(축제 스킨).
  void paint(
    Canvas c,
    Size size,
    Map<String, int> look,
    HdShipColors col, {
    String? glowPart,
    double glow = 0,
    double recoil = 0,
    double billow = 0,
    bool flash = false,
    double alpha = 1,
    bool rainbow = false,
    double now = 0,
  }) {
    final w = size.width;
    final h = size.height;
    final k = _k..ink.strokeWidth = math.max(1.1, w * 0.045);
    int st(String p, int max) => (look[p] ?? 0).clamp(1, max);
    final hullSt = st('hull', 7);
    // 선체 길이·폭: 단계마다 커진다(1단계 = 칸의 78%·62% → 7단계 = 96%·92%).
    final len = h * (0.78 + 0.18 * (hullSt - 1) / 6);
    final hw = w * (0.31 + 0.15 * (hullSt - 1) / 6);
    final hull = _hullPath(len, hw);
    // 바다 그림자(오른쪽 아래)
    k.fill.color = const Color(0x4D0B1E3A);
    c.drawPath(hull.shift(Offset(w * 0.06, h * 0.04)), k.fill);
    final layered = flash || alpha < 1;
    if (layered) {
      _layer
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..colorFilter = flash ? const ColorFilter.mode(Color(0xCCFFFFFF), BlendMode.srcATop) : null;
      c.saveLayer(Rect.fromCenter(center: Offset.zero, width: w * 2.4, height: h * 1.6), _layer);
    }
    _part(c, 'hull', glowPart, glow, w, h, () => _hull(c, hull, len, hw, hullSt, col));
    _part(c, 'cargo', glowPart, glow, w, h, () => _cargo(c, len, hw, st('cargo', 7)));
    _part(c, 'cannon', glowPart, glow, w, h, () => _cannons(c, len, hw, st('cannon', 7), recoil));
    _crew(c, len, hw);
    _part(c, 'sail', glowPart, glow, w, h, () => _sails(c, len, hw, st('sail', 5), billow, col, rainbow));
    _part(c, 'crowsnest', glowPart, glow, w, h, () => _nest(c, len, st('crowsnest', 6), col, now));
    if (layered) c.restore();
  }

  /// 부위 하나 + (축하면) 그 부위를 조금 크게 흰빛으로 한 번 더.
  void _part(Canvas c, String part, String? glowPart, double glow, double w, double h, void Function() draw) {
    draw();
    if (glowPart != part || glow <= 0) return;
    _layer
      ..color = Color.fromRGBO(255, 255, 255, glow)
      ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);
    c
      ..saveLayer(Rect.fromCenter(center: Offset.zero, width: w * 2.4, height: h * 1.6), _layer)
      ..scale(1 + 0.12 * glow);
    draw();
    c.restore();
  }

  /// 선체 윤곽: 뾰족한 뱃머리(위) → 둥근 배 → 평평한 고물(아래).
  static Path _hullPath(double len, double hw) {
    final top = -len / 2;
    final bot = len / 2;
    return Path()
      ..moveTo(0, top)
      ..cubicTo(hw * 0.75, top + len * 0.12, hw * 1.02, top + len * 0.32, hw, top + len * 0.55)
      ..quadraticBezierTo(hw * 0.98, bot - len * 0.08, hw * 0.72, bot)
      ..lineTo(-hw * 0.72, bot)
      ..quadraticBezierTo(-hw * 0.98, bot - len * 0.08, -hw, top + len * 0.55)
      ..cubicTo(-hw * 1.02, top + len * 0.32, -hw * 0.75, top + len * 0.12, 0, top)
      ..close();
  }

  void _hull(Canvas c, Path hull, double len, double hw, int stage, HdShipColors col) {
    final k = _k;
    // 뱃전(테) → 갑판(안쪽) — 테 두께는 단계마다 굵게, 4단계부터 금 테두리, 3단계부터 고물 선실
    final rimW = hw * (0.16 + 0.02 * stage);
    final deck = _hullPath(len - rimW * 2.2, hw - rimW);
    k
      ..blob(c, hull, col.rim, col.rimD)
      ..blob(c, deck, col.deck, col.deckD, gloss: false, line: 0.5);
    // 판자 줄
    final iw = k.ink.strokeWidth;
    k.ink
      ..strokeWidth = iw * 0.3
      ..color = col.deckD;
    for (var i = -2; i <= 2; i++) {
      final x = i * (hw - rimW) * 0.36;
      c.drawLine(Offset(x, -len * 0.3), Offset(x, len * 0.42), k.ink);
    }
    k.ink
      ..strokeWidth = iw
      ..color = HdKit.inkColor;
    if (stage >= 4) {
      k.ink
        ..strokeWidth = iw * 0.45
        ..color = const Color(0xFFFFD45A);
      c.drawPath(_hullPath(len - rimW * 0.9, hw - rimW * 0.45), k.ink);
      k.ink
        ..strokeWidth = iw
        ..color = HdKit.inkColor;
    }
    if (stage >= 3) {
      final cab = Rect.fromCenter(center: Offset(0, len * 0.36), width: hw * 1.1, height: len * 0.16);
      k.blob(
        c,
        Path()..addRRect(RRect.fromRectAndRadius(cab, Radius.circular(hw * 0.12))),
        col.rim,
        col.rimD,
        gloss: false,
        line: 0.6,
      );
      k.fill.color = const Color(0xFFFFE89A);
      for (final x in const [-0.3, 0.0, 0.3]) {
        c.drawRect(Rect.fromCenter(center: Offset(x * hw, len * 0.36), width: hw * 0.14, height: len * 0.05), k.fill);
      }
    }
    k.shine(c, hull.getBounds());
  }
}
