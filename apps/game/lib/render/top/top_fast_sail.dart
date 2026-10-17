import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:pirate_dot/render/top/top_label.dart';
import 'package:pirate_dot/render/top/top_marks.dart' show edgeVignette, vignetteBump;

/// 빠른 항해 돌파 연출 (S5 fast-sail, docs/specs/platform-fast-sail-breakthrough.md, 사용자 '꿈과 희망을 심어 주는 웅대한
/// 애니메이션 — 점점 빨라지다 순식간에, 피날레'):
/// - 시작: texts.start 금빛 띠 컷인(1.2초). 바다·속도선은 피버 황금 질주를 쓴다(TopFever가 fastSail 동안 켠다).
/// - 격파(BreakthroughStrike): 배에서 보스로 금·흰 일제 사격 줄기 → 거대 폭발(TopImpact) → '격파!' 스탬프 + ×콤보.
///   rush(순식간)는 흰 섬광 터널(가장자리부터 하얘짐), finale는 슬로모션 0.6초 뒤 피날레 폭발 + '돌파!'.
/// - 끝(FastSailEnded): '스테이지 from → to 돌파!' 금빛 띠 + 폭죽.
class TopFastSail {
  /// 화면 문구 — UI(S4)가 AppLocalizations로 채워 BattleGame.topTexts로 넣는다(렌더 레인은 ARB가 없다). 기본은 영어.
  TopTexts texts = const TopTexts();

  double _startAt = -1000000000;
  double _endAt = -1000000000;
  int _from = 0;
  int _to = 0;
  final List<_Strike> _strikes = [];
  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _label = TopLabel();
  static const _gold = Color(0xFFFFD84A);
  static const _orange = Color(0xFFFF8A2A);

  void started(int from, int to, double now) {
    _startAt = now;
    _from = from;
    _to = to;
  }

  void ended(int from, int to, double now) {
    _endAt = now;
    _from = from;
    _to = to;
  }

  void strike(double x, double y, int combo, String phase, double speed, double now) {
    if (_strikes.length >= 10) _strikes.removeAt(0);
    _strikes.add(_Strike(x, y, combo, phase, speed, now));
  }

  void clear() {
    _strikes.clear();
    _startAt = _endAt = -1000000000;
  }

  /// 전장 좌표: 일제 사격 줄기(배 → 보스, 0.18초).
  void paintWorld(Canvas c, double now, Offset ship) {
    _strikes.removeWhere((s) => now - s.ms > 1600);
    for (final s in _strikes) {
      final age = now - s.ms;
      if (age < 0 || age > 180) continue;
      final t = age / 180;
      final target = Offset(s.x, s.y);
      for (var k = 0; k < 6; k++) {
        final from = ship + Offset((k - 2.5) * 6, 0);
        final head = Offset.lerp(from, target, math.min(1, t * 1.6))!;
        _line
          ..strokeWidth = 3
          ..color = (k.isEven ? _gold : const Color(0xFFFFFFFF)).withValues(alpha: 0.9 * (1 - t * 0.5));
        c.drawLine(Offset.lerp(from, head, 0.5)!, head, _line);
      }
    }
  }

  /// 화면 dp 좌표: 컷인·스탬프·터널·마무리 띠·폭죽. [flash] 꺼짐이면 흰 터널·섬광을 뺀다.
  void paintScreen(Canvas c, Size box, double now, {required bool flash}) {
    _band(c, box, now - _startAt, 1200, texts.start, 30);
    if (_strikes.isNotEmpty) {
      final s = _strikes.last;
      final age = now - s.ms;
      if (s.phase == 'rush' && flash && age < 220) {
        // 흰 섬광 터널 대신 금빛 가장자리(약하게).
        edgeVignette(c, Offset.zero & box, _gold, 0.25 * vignetteBump(age / 220) * math.min(1, s.speed / 6));
      }
      final finale = s.phase == 'finale';
      final life = finale ? 1400.0 : 700.0; // 피날레 스탬프는 오래(슬로모션 뒤에도 보이게)
      if (age < life) {
        final t = age / life;
        final pop = t < 0.15 ? 1.6 - 0.6 * (t / 0.15) : 1.0;
        final center = Offset(box.width / 2, box.height * 0.3);
        c
          ..save()
          ..translate(center.dx, center.dy)
          ..rotate(-0.12)
          ..scale(pop);
        _text(
          c,
          finale ? texts.finale : texts.strike,
          Offset.zero,
          finale ? 54 : 40,
          alpha: 1 - math.max(0, t - 0.7) / 0.3,
        );
        if (s.combo > 1) {
          _text(
            c,
            '×${s.combo}',
            Offset(0, finale ? 44 : 34),
            24,
            alpha: 1 - math.max(0, t - 0.7) / 0.3,
            color: _orange,
          );
        }
        c.restore();
      }
    }
    final end = now - _endAt;
    _band(c, box, end, 2200, texts.ended(_from, _to), 26);
    if (end >= 0 && end < 2200) _fireworks(c, box, end);
  }

  /// 금빛 띠 컷인: 오른쪽에서 들어와 머물다 왼쪽으로(전체 [life]ms).
  void _band(Canvas c, Size box, double age, double life, String text, double size) {
    if (age < 0 || age >= life) return;
    final t = age / life;
    final x = t < 0.15 ? box.width * (1 - t / 0.15) : (t > 0.85 ? -box.width * (t - 0.85) / 0.15 : 0.0);
    final y = box.height * 0.42;
    final h = size * 2.2;
    _fill.shader = const LinearGradient(
      colors: [Color(0xCC8A4A00), Color(0xEEFFB31F), Color(0xCC8A4A00)],
    ).createShader(Rect.fromLTWH(x, y - h / 2, box.width, h));
    c.drawRect(Rect.fromLTWH(x, y - h / 2, box.width, h), _fill);
    _fill.shader = null;
    _line
      ..strokeWidth = 2
      ..color = const Color(0xFFFFF6C8);
    c
      ..drawLine(Offset(x, y - h / 2), Offset(x + box.width, y - h / 2), _line)
      ..drawLine(Offset(x, y + h / 2), Offset(x + box.width, y + h / 2), _line);
    _text(c, text, Offset(x + box.width / 2, y), size);
  }

  void _fireworks(Canvas c, Size box, double age) {
    for (var b = 0; b < 6; b++) {
      final at = age - b * 280;
      if (at < 0 || at > 900) continue;
      final t = at / 900;
      final cx = box.width * (0.15 + ((b * 37) % 70) / 100);
      final cy = box.height * (0.12 + ((b * 23) % 25) / 100);
      final col = [_gold, _orange, const Color(0xFFFF6FD8), const Color(0xFF4AD8FF)][b % 4];
      for (var k = 0; k < 14; k++) {
        final a = k * 2 * math.pi / 14;
        final d = 46 * (1 - (1 - t) * (1 - t));
        _fill.color = col.withValues(alpha: 1 - t);
        c.drawCircle(Offset(cx + math.cos(a) * d, cy + math.sin(a) * d + 18 * t * t), 2.2, _fill);
      }
    }
  }

  void _text(Canvas c, String s, Offset center, double size, {double alpha = 1, Color color = _gold}) =>
      _label.draw(c, s, center, size, alpha: alpha, color: color);
}

class _Strike {
  _Strike(this.x, this.y, this.combo, this.phase, this.speed, this.ms);
  final double x;
  final double y;
  final int combo;
  final String phase;
  final double speed;
  final double ms;
}

/// 빠른 항해 돌파 화면 문구 (UI가 지역화해 넣는다).
class TopTexts {
  const TopTexts({
    this.start = 'FAST SAIL BREAKTHROUGH!',
    this.strike = 'BREAK!',
    this.finale = 'BREAKTHROUGH!',
    this.ended = _endedEn,
    this.wanted = 'WANTED',
    this.fled = 'Fled!',
    this.newCrew = 'NEW CREW!',
  });

  final String start;
  final String strike;
  final String finale;
  final String Function(int from, int to) ended;

  /// 현상금 수배 포스터 머리말·도망 문구.
  final String wanted;
  final String fled;

  /// 새 동료 카드 위 문구(피드백 #17, S4 ARB).
  final String newCrew;

  static String _endedEn(int from, int to) => 'STAGE $from → $to CLEARED!';
}
