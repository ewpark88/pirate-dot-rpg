import 'dart:math' as math;
import 'dart:ui';

/// 도감 v2 보스 패턴 연출 (docs/specs/platform-bestiary-v2.md): 먹물(InkCloud)·삼키기(BossSwallowed)·분열(BossSplit)·
/// 자폭(BomberBlast는 TopImpact가 맡는다). 전장 좌표.
/// - 먹물: 짙은 남보라 얼룩이 촉수처럼 퍼졌다가 ticks 동안 소용돌이치고 끝에 옅어진다(안의 적은 조준 안 됨 — 엔진).
/// - 삼키기: 먹힌 적이 보스 입으로 빨려 들어가며 작아지고, 보스 자리에 초록 '+회복' 빛과 '꿀꺽' 고리.
/// - 분열: 보스 자리에서 끈적한 물방울이 튀며 새 몸이 있는 쪽으로 띠가 늘어났다 끊긴다.
class TopBestiary {
  final List<_Ink> _inks = [];
  final List<_Gulp> _gulps = [];
  final List<_Split> _splits = [];

  final _fill = Paint()..isAntiAlias = false;
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  static const _inkGrowMs = 420.0;
  static const _inkFadeMs = 500.0;
  static const _gulpMs = 520.0;
  static const _splitMs = 600.0;

  void ink(double x, double y, double radius, double ms, double now) {
    if (_inks.length >= 4) _inks.removeAt(0);
    _inks.add(_Ink(Offset(x, y), radius, ms, now));
  }

  /// 보스 [boss]가 [eaten] 자리의 적들을 삼켰다.
  void gulp(Offset boss, List<Offset> eaten, double now) {
    if (_gulps.length >= 3) _gulps.removeAt(0);
    _gulps.add(_Gulp(boss, eaten, now));
  }

  void split(Offset from, Offset to, double now) {
    if (_splits.length >= 4) _splits.removeAt(0);
    _splits.add(_Split(from, to, now));
  }

  void clear() {
    _inks.clear();
    _gulps.clear();
    _splits.clear();
  }

  /// 물 위·적 아래 층(TopHits.paint — 적보다 먼저).
  void paint(Canvas c, double now) {
    _inks.removeWhere((k) => now - k.at > k.ms + _inkFadeMs);
    for (final k in _inks) {
      final age = now - k.at;
      final grow = math.min<double>(1, age / _inkGrowMs);
      final fade = age > k.ms ? 1 - (age - k.ms) / _inkFadeMs : 1.0;
      final r = k.r * (0.3 + 0.7 * (1 - (1 - grow) * (1 - grow)));
      _fill.color = Color.fromRGBO(30, 20, 50, 0.55 * fade);
      c.drawCircle(k.c, r, _fill);
      // 촉수처럼 뻗은 얼룩 8개 + 소용돌이
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + age / 900;
        final d = r * (0.75 + 0.15 * math.sin(age / 200 + i));
        _fill.color = Color.fromRGBO(40, 26, 70, 0.5 * fade);
        c.drawCircle(k.c + Offset(math.cos(a) * d, math.sin(a) * d), r * 0.32, _fill);
      }
      _ring
        ..strokeWidth = 1.5
        ..color = Color.fromRGBO(120, 90, 170, 0.5 * fade);
      for (var i = 0; i < 2; i++) {
        c.drawArc(Rect.fromCircle(center: k.c, radius: r * (0.4 + 0.25 * i)), age / 300 + i * 2, 2.2, false, _ring);
      }
    }
  }

  /// 적 위 층(TopHits.paintOver): 삼키기·분열.
  void paintOver(Canvas c, double now) {
    _gulps.removeWhere((g) => now - g.at > _gulpMs);
    for (final g in _gulps) {
      final t = (now - g.at) / _gulpMs;
      // 먹힌 적: 보스 입(조금 앞)으로 빨려 들어가며 작아지는 어두운 점 + 꼬리
      final mouth = g.boss + const Offset(0, -10);
      for (final e in g.eaten) {
        final k = math.min<double>(1, t * 1.6);
        final p = Offset.lerp(e, mouth, k * k)!;
        _ring
          ..strokeWidth = 2
          ..color = Color.fromRGBO(255, 255, 255, 0.5 * (1 - k));
        c.drawLine(Offset.lerp(e, mouth, math.max(0, k * k - 0.15))!, p, _ring);
        _fill.color = Color.fromRGBO(40, 30, 50, 1 - k);
        c.drawCircle(p, 4 * (1 - k) + 1, _fill);
      }
      if (t > 0.5) {
        final k = (t - 0.5) / 0.5;
        _ring
          ..strokeWidth = 6 * (1 - k) + 2
          ..color = Color.fromRGBO(90, 255, 120, 1 - k);
        c.drawCircle(g.boss, 16 + 26 * k, _ring);
        _fill.color = Color.fromRGBO(120, 255, 150, 0.5 * (1 - k));
        c.drawCircle(g.boss, 22, _fill);
      }
    }
    _splits.removeWhere((sp) => now - sp.at > _splitMs);
    for (final sp in _splits) {
      final t = (now - sp.at) / _splitMs;
      // 늘어나는 끈적한 띠(0~0.5) → 끊기며 물방울 튐(0.5~1)
      if (t < 0.5) {
        final k = t / 0.5;
        _ring
          ..strokeWidth = 12 * (1 - k) + 3
          ..color = const Color.fromRGBO(235, 250, 255, 0.95);
        c.drawLine(sp.from, Offset.lerp(sp.from, sp.to, k)!, _ring);
      } else {
        final k = (t - 0.5) / 0.5;
        for (final at in [sp.from, sp.to]) {
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4 + 0.3;
            final d = 6 + 20 * k;
            _fill.color = Color.fromRGBO(200, 240, 255, 1 - k);
            c.drawCircle(
              at + Offset(math.cos(a) * d, math.sin(a) * d - 8 * k * (1 - k) * 4),
              2.4 * (1 - k) + 0.8,
              _fill,
            );
          }
        }
      }
    }
  }
}

class _Ink {
  _Ink(this.c, this.r, this.ms, this.at);
  final Offset c;
  final double r;
  final double ms;
  final double at;
}

class _Gulp {
  _Gulp(this.boss, this.eaten, this.at);
  final Offset boss;
  final List<Offset> eaten;
  final double at;
}

class _Split {
  _Split(this.from, this.to, this.at);
  final Offset from;
  final Offset to;
  final double at;
}
