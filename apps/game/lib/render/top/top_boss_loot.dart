import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/top/top_loot_bits.dart';

/// 보스 처치 보상 연출 (사용자 피드백 #18 '보스 처치 보상이 확실히 보이게', 2026-10-17):
/// 보스 자리에서 연쇄 폭발·빛줄기·충격파 → 금화·젬·카드가 크게 튀어나와 잠깐 떠 있다가 배로 빨려 들어간다(도착마다 배 둘레 반짝).
/// 화면 연출만 — 금액은 기존 코인 흐름(Kill)이 UI로 나른다. 모든 조각은 시작 시각과 번호로만 정해진다(결정론, 할당은 시작 때 한 번).
class TopBossLoot {
  final List<_Burst> _bursts = [];

  static const _blastGapMs = 90.0;
  static const _blastMs = 420.0;
  static const _ringMs = 520.0;
  static const _popAtMs = 260.0;
  static const _popMs = 420.0;
  static const _holdUntilMs = 1050.0;
  static const _flyMs = 420.0;
  static const _maxBursts = 3;

  /// 끝까지 걸리는 시간(ms) — 테스트·정리용.
  static const totalMs = 2600.0;

  /// 보스가 ([at])에서 쓰러졌다. [lite]면 조각 절반(절전·시트가 가림).
  void burst(double now, Offset at, {required bool lite, double size = 1.7}) =>
      _add(_Burst(now, at, lite ? 14 : 28, lite ? 5 : 9, size.clamp(1.0, 2.2)));

  /// 보물상자가 열렸다(피드백 #15, 탭·광고 둘 다 ChestOpened): 폭발 대신 하늘로 솟는 금빛 기둥 + 금화(또는 젬) 분수.
  void chest(double now, Offset at, {required bool lite, bool gems = false}) {
    final b = _Burst(now, at, gems ? 0 : (lite ? 10 : 20), 0, 1.3, style: LootStyle.chest);
    if (gems) b.gems = 5;
    _add(b);
  }

  /// 광고 보상을 받았다(순풍·자동 강화·오프라인 ×2 등 — 배에 버프): 배에서 금빛 고리·별가루가 솟는다.
  void reward(double now, Offset ship) => _add(_Burst(now, ship, 0, 0, 1.2, style: LootStyle.reward));

  void _add(_Burst b) {
    if (_bursts.length >= _maxBursts) _bursts.removeAt(0);
    _bursts.add(b);
  }

  /// 젬 [n]개를 가장 최근 터짐에 더한다(BossCleared·DexFirstKill). 터짐이 없으면 무시.
  void gems(int n) {
    if (n <= 0 || _bursts.isEmpty) return;
    final b = _bursts.last;
    b.gems = math.min(7, b.gems + math.max(3, (n / 3).ceil()));
  }

  /// 카드(선원 초상·등급 색)를 가장 최근 터짐에 더한다 — 피드백 #17, 카드 이벤트가 오면 연결.
  void card(String crewId, int color) {
    if (_bursts.isEmpty) return;
    final b = _bursts.last;
    if (b.cards.length < 5) b.cards.add((crewId, color));
  }

  bool get active => _bursts.isNotEmpty;

  void clear() => _bursts.clear();

  final _paint = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final _ray = Path();
  final _bits = LootBits();

  /// 전장 좌표로 그린다(적 위 층). [ship] = 배 중심.
  void paint(Canvas c, double now, Offset ship, SpriteDraw? sprites, {required bool flash}) {
    _bursts.removeWhere((b) => now - b.ms > totalMs);
    for (final b in _bursts) {
      final age = now - b.ms;
      if (age < 0) continue;
      if (b.style != LootStyle.boss) _bits.pillar(c, b.at, age, wide: b.style == LootStyle.reward);
      if (b.style == LootStyle.reward) _bits.stars(c, b.at, age);
      _rays(c, b, age);
      if (flash && age < 160) {
        _paint.color = Color.fromRGBO(255, 248, 210, 0.85 * (1 - age / 160));
        c.drawCircle(b.at, 26 * b.size * (0.6 + age / 400), _paint);
      }
      _rings(c, b, age, flash: flash);
      for (var k = 0; k < b.blasts; k++) {
        _blast(c, b, k, age - k * _blastGapMs);
      }
      var arrivals = 0;
      for (var i = 0; i < b.coins; i++) {
        arrivals += _piece(c, b, i, age, ship, sprites, kind: 0);
      }
      for (var i = 0; i < b.gems; i++) {
        arrivals += _piece(c, b, i, age, ship, sprites, kind: 1);
      }
      for (var i = 0; i < b.cards.length; i++) {
        arrivals += _piece(c, b, i, age, ship, sprites, kind: 2);
      }
      if (arrivals > 0) _absorb(c, ship, arrivals);
    }
  }

  /// 회전하는 금빛 빛줄기(0~700ms).
  void _rays(Canvas c, _Burst b, double age) {
    const ms = 700.0;
    if (age >= ms) return;
    final t = age / ms;
    final r = (40 + 50 * t) * b.size;
    final a0 = age / 900;
    _paint.color = Color.fromRGBO(255, 214, 90, 0.32 * (1 - t));
    _ray.reset();
    for (var k = 0; k < 10; k++) {
      final a = a0 + k * math.pi / 5;
      _ray
        ..moveTo(b.at.dx, b.at.dy)
        ..lineTo(b.at.dx + math.cos(a - 0.09) * r, b.at.dy + math.sin(a - 0.09) * r)
        ..lineTo(b.at.dx + math.cos(a + 0.09) * r, b.at.dy + math.sin(a + 0.09) * r)
        ..close();
    }
    c.drawPath(_ray, _paint);
  }

  /// 충격파 고리 둘(두꺼운 흰금 → 얇은 주황).
  void _rings(Canvas c, _Burst b, double age, {required bool flash}) {
    for (var k = 0; k < 2; k++) {
      final t = (age - k * 180) / _ringMs;
      if (t < 0 || t >= 1) continue;
      final e = 1 - (1 - t) * (1 - t);
      _ring
        ..strokeWidth = (k == 0 ? 4 : 2) * (1 - t) + 1
        ..color = k == 0
            ? Color.fromRGBO(255, 244, 196, (flash ? 0.9 : 0.6) * (1 - t))
            : Color.fromRGBO(255, 150, 60, 0.8 * (1 - t));
      c.drawCircle(b.at, (8 + 70 * e) * b.size, _ring);
    }
  }

  /// 연쇄 폭발 하나: 불덩이(노랑→주황→빨강) + 늦게 퍼지는 연기 + 불꽃 튐.
  void _blast(Canvas c, _Burst b, int k, double age) {
    if (age < 0 || age >= _blastMs) return;
    final t = age / _blastMs;
    final a = k * 2.4;
    final d = (k == 0 ? 0 : 6 + (k * 7) % 15) * b.size;
    final at = b.at + Offset(math.cos(a) * d, math.sin(a) * d);
    final big = (9 + (k % 3) * 4) * b.size;
    if (t > 0.3) {
      final s = (t - 0.3) / 0.7;
      _paint.color = Color.fromRGBO(60, 48, 56, 0.55 * (1 - s));
      c.drawCircle(at + Offset(0, -4 * s), big * (0.7 + 0.6 * s), _paint);
    }
    final grow = math.min<double>(1, t * 4);
    final fade = t < 0.5 ? 1.0 : 1 - (t - 0.5) * 2;
    _paint.color = Color.fromRGBO(220, 60, 30, 0.9 * fade);
    c.drawCircle(at, big * grow, _paint);
    _paint.color = Color.fromRGBO(255, 150, 40, fade);
    c.drawCircle(at, big * grow * 0.72, _paint);
    _paint.color = Color.fromRGBO(255, 236, 120, fade);
    c.drawCircle(at, big * grow * 0.42 * (1 - t * 0.6), _paint);
    for (var j = 0; j < 6; j++) {
      final sa = a + j * math.pi / 3 + 0.4;
      final sd = big * (0.6 + 1.4 * t);
      _paint.color = Color.fromRGBO(255, 220, 110, 1 - t);
      c.drawRect(Rect.fromLTWH(at.dx + math.cos(sa) * sd, at.dy + math.sin(sa) * sd, 2, 2), _paint);
    }
  }

  /// 조각 하나(0 금화·1 젬·2 카드): 튀어나옴(포물선 높이·그림자) → 떠 있음(살짝 위아래) → 배로 빨려 들어감(꼬리).
  /// 이번 프레임에 배에 닿았으면 1.
  int _piece(Canvas c, _Burst b, int i, double age, Offset ship, SpriteDraw? sprites, {required int kind}) {
    final order = kind == 0 ? i : (kind == 1 ? b.coins ~/ 2 + i * 3 : b.coins + i * 4);
    final pop = age - _popAtMs - order * 8 - kind * 120;
    if (pop < 0) return 0;
    const golden = 2.39996;
    final ang = kind == 0 ? i * golden : -math.pi / 2 + (i - (kind == 1 ? b.gems : b.cards.length) / 2 + 0.5) * 0.55;
    final dist = (kind == 0 ? 18 + (i * 13) % 30 : 30.0 + kind * 6) * b.size;
    final land = b.at + Offset(math.cos(ang) * dist, math.sin(ang) * dist);
    final hold = _holdUntilMs + order * 22 + kind * 160;
    final flyT = (age - hold) / _flyMs;
    if (flyT >= 1) return flyT < 1 + 34 / _flyMs ? 1 : 0;
    Offset at;
    double lift;
    if (flyT < 0) {
      final t = math.min<double>(1, pop / _popMs);
      final e = 1 - math.pow(1 - t, 3).toDouble();
      at = Offset.lerp(b.at, land, e)!;
      lift = math.sin(math.pi * t) * (kind == 0 ? 26 : 36) + (t >= 1 ? math.sin((age + i * 90) / 160) * 1.5 : 0);
      if (lift > 0.5) {
        _paint.color = const Color.fromRGBO(10, 30, 60, 0.3);
        c.drawOval(Rect.fromCenter(center: at, width: 7, height: 3), _paint);
      }
    } else {
      final e = flyT * flyT * flyT;
      at = Offset.lerp(land, ship, e)!;
      lift = 0;
      final back = Offset.lerp(
        land,
        ship,
        math.max(0, flyT - 0.18) * math.max(0, flyT - 0.18) * math.max(0, flyT - 0.18),
      )!;
      _ring
        ..strokeWidth = kind == 0 ? 2 : 3
        ..color = kind == 1 ? const Color(0xAA9CF6FF) : const Color(0xAAFFE27A);
      c.drawLine(back, at, _ring);
    }
    final p = at - Offset(0, lift);
    final spin = ((age / 70).floor() + i) % 4;
    switch (kind) {
      case 0:
        final s = 13.0 * (flyT > 0.7 ? 1 - (flyT - 0.7) : 1);
        if (sprites == null || !sprites.drawSmoothFrame(c, 'coin_hd', spin, p.dx, p.dy, s, s)) {
          _paint.color = const Color(0xFFFFD24A);
          c.drawCircle(p, s / 2, _paint);
        }
      case 1:
        c
          ..save()
          ..translate(p.dx, p.dy)
          ..scale(1.6);
        _bits.gem(c, Offset.zero, age);
        c.restore();
      default:
        _bits.card(c, p, b.cards[i], age, sprites);
    }
    return 0;
  }

  /// 배 둘레 흡수 반짝(이번 프레임 도착 수만큼 굵게).
  void _absorb(Canvas c, Offset ship, int n) {
    _ring
      ..strokeWidth = math.min(4, 1 + n * 0.5)
      ..color = const Color(0xCCFFE27A);
    c.drawCircle(ship, 14 + math.min(8, n * 1.0), _ring);
  }
}

/// 터짐 종류: 보스 처치(연쇄 폭발) · 보물상자(금빛 기둥) · 광고 보상(배에서 고리·별가루).
enum LootStyle { boss, chest, reward }

class _Burst {
  _Burst(this.ms, this.at, this.coins, this.blasts, this.size, {this.style = LootStyle.boss});
  final LootStyle style;
  final double ms;
  final Offset at;
  final int coins;
  final int blasts;
  final double size;
  int gems = 0;
  final List<(String, int)> cards = [];
}
