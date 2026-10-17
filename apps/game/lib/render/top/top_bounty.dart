import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';

/// 현상금 사냥 B3 연출 (S5 요청서 platform-bounty-b3.md, S1):
/// - 시작(BountyStarted): 수배 포스터 컷인 — 양피지 + 보스 초상(`bosses/<id>.png`) + 'WANTED'(지역화) + 등급 별, 위에서 떨어져 1.2초.
/// - 전투 중(BattleView.bounty): 현상금 보스 머리 위 작은 포스터 핀(빨간 핀 + 양피지 + 해골 표).
/// - 처치(BountyCleared): 보상 숫자가 보스 자리에서 올라감(종류별 색). 실패(BountyFailed): 회색 '도망쳤다'(지역화) + 연기.
/// 타이머는 UI 진행 게이지(S4)가 bounty.ticksLeft로 그린다.
class TopBounty {
  /// 지역화 문구(UI가 BattleGame.topTexts로 넣는다).
  String wanted = 'WANTED';
  String fled = 'Fled!';

  String _boss = '';
  int _tier = 1;
  double _startAt = -1000000000;
  double _endAt = -1000000000;
  bool _cleared = false;
  String _rewardText = '';
  int _rewardColor = 0xFFFFD84A;
  Offset _endAt2 = Offset.zero;
  final _fill = Paint();
  final _line = Paint()..style = PaintingStyle.stroke;
  final Map<String, (TextPainter, TextPainter)> _texts = {};
  static const _parch = Color(0xFFF2DFB0);
  static const _parchDark = Color(0xFFB98A4A);
  static const _ink = Color(0xFF5A2E14);

  void started(String bossId, int tier, double now) {
    _boss = bossId;
    _tier = tier;
    _startAt = now;
  }

  void cleared(String type, int amount, Offset at, double now) {
    _cleared = true;
    _endAt = now;
    _endAt2 = at;
    _rewardText = '+$amount';
    _rewardColor = switch (type) {
      'gems' || 'gifts' => 0xFF4AD8FF,
      'cards' => 0xFFC07BFF,
      'mapPieces' => 0xFFE0A050,
      _ => 0xFFFFD84A,
    };
  }

  void failed(Offset at, double now) {
    _cleared = false;
    _endAt = now;
    _endAt2 = at;
  }

  void clear() => _startAt = _endAt = -1000000000;

  /// 전장 좌표: 현상금 보스 머리 위 포스터 핀 + 끝 연출(보상 숫자·도망 연기).
  void paintWorld(Canvas c, double now, List<EnemyPose> poses, int poseCount, {required bool active}) {
    if (active) {
      for (var k = 0; k < poseCount; k++) {
        final e = poses[k];
        if (!e.boss) continue;
        final at = Offset(e.drawX, e.drawY - 30 + math.sin(now / 300) * 1.5);
        _fill.color = _parch;
        c.drawRect(Rect.fromCenter(center: at, width: 12, height: 14), _fill);
        _line
          ..strokeWidth = 1
          ..color = _parchDark;
        c.drawRect(Rect.fromCenter(center: at, width: 12, height: 14), _line);
        // 해골 표(작은 흰 머리 + 눈 둘)
        _fill.color = _ink;
        c
          ..drawCircle(at + const Offset(0, 1), 3, _fill)
          ..drawRect(Rect.fromCenter(center: at + const Offset(0, 4.5), width: 3, height: 2), _fill);
        _fill.color = _parch;
        c
          ..drawCircle(at + const Offset(-1.2, 0.6), 0.8, _fill)
          ..drawCircle(at + const Offset(1.2, 0.6), 0.8, _fill);
        _fill.color = const Color(0xFFE8443A);
        c.drawCircle(at + const Offset(0, -7), 1.6, _fill);
      }
    }
    final age = now - _endAt;
    if (age < 0 || age > 1400) return;
    final t = age / 1400;
    if (_cleared) {
      _text(
        c,
        _rewardText,
        _endAt2 - Offset(0, 20 + 30 * t),
        28,
        color: Color(_rewardColor),
        alpha: 1 - math.max(0, t - 0.6) / 0.4,
        scale: 0.6,
      );
    } else {
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3;
        _fill.color = Color.fromRGBO(200, 200, 210, 0.6 * (1 - t));
        c.drawCircle(_endAt2 + Offset(math.cos(a), math.sin(a)) * (6 + 14 * t) - Offset(0, 10 * t), 4 + 3 * t, _fill);
      }
      _text(c, fled, _endAt2 - Offset(0, 22 + 12 * t), 16, color: const Color(0xFFB8C0CC), alpha: 1 - t, scale: 0.4);
    }
  }

  /// 화면 dp: 수배 포스터 컷인.
  void paintScreen(Canvas c, Size box, double now, SpriteDraw sprites) {
    final age = now - _startAt;
    if (age < 0 || age >= 1200) return;
    final t = age / 1200;
    final drop = t < 0.18 ? 1 - Curves.easeOutBack.transform(t / 0.18) : 0.0;
    final out = t > 0.85 ? (t - 0.85) / 0.15 : 0.0;
    final w = math.min<double>(220, box.width * 0.62);
    final h = w * 1.25;
    final center = Offset(box.width / 2, box.height * 0.4 - drop * box.height * 0.5 - out * box.height * 0.6);
    c
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-0.05 + 0.05 * math.sin(age / 180) * (1 - t));
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    _fill.color = const Color(0x55000000);
    c.drawRect(r.shift(const Offset(5, 6)), _fill);
    _fill.color = _parch;
    c.drawRect(r, _fill);
    _line
      ..strokeWidth = 3
      ..color = _parchDark;
    c.drawRect(r.deflate(4), _line);
    _text(c, wanted, Offset(0, -h * 0.38), w * 0.17, color: const Color(0xFFE8443A));
    // HD 보스(개편 ④)면 카툰 그림을 바로(옛 도트 초상 대신 — S1 실기기 p03), 아니면 도트.
    final hd = hdBosses[_boss];
    final portrait = hd == null ? sprites.sheet('boss:$_boss') : null;
    if (hd != null) {
      final r = math.min(w * 0.7, h * 0.42) / (2 * hd.extent);
      c
        ..save()
        ..translate(0, -h * 0.02);
      _hd
        ..mood = HdMood.idle
        ..begin(r);
      hd.draw(_hd, c, r, 0);
      c.restore();
    } else if (portrait != null) {
      final s = math.min(w * 0.7 / portrait.frameW, h * 0.42 / portrait.frameH);
      sprites.draw(c, 'boss:$_boss', 0, -h * 0.02, w: portrait.frameW * s, h: portrait.frameH * s);
    }
    for (var i = 0; i < _tier.clamp(1, 5); i++) {
      _star(c, Offset((i - (_tier.clamp(1, 5) - 1) / 2) * w * 0.14, h * 0.33), w * 0.05);
    }
    c.restore();
  }

  final _starPath = Path();
  final _hd = HdKit();

  void _star(Canvas c, Offset at, double s) {
    _starPath.reset();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? s : s * 0.45;
      final p = at + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? _starPath.moveTo(p.dx, p.dy) : _starPath.lineTo(p.dx, p.dy);
    }
    _starPath.close();
    _fill.color = const Color(0xFFFFC53D);
    c.drawPath(_starPath, _fill);
    _line
      ..strokeWidth = 1.5
      ..color = _ink;
    c.drawPath(_starPath, _line);
  }

  void _text(Canvas c, String s, Offset center, double size, {Color color = _ink, double alpha = 1, double scale = 1}) {
    final key = '$s|$size|${color.toARGB32()}';
    final pair = _texts.putIfAbsent(key, () {
      if (_texts.length > 30) {
        for (final (a, b) in _texts.values) {
          a.dispose();
          b.dispose();
        }
        _texts.clear();
      }
      TextPainter make(TextStyle style) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final base = TextStyle(fontFamily: 'Jua', fontFamilyFallback: const ['GowunDodumSymbols'], fontSize: size);
      return (
        make(
          base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF1B2A4A),
          ),
        ),
        make(base.copyWith(color: color)),
      );
    });
    final (outline, fill) = pair;
    c
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    final at = Offset(-fill.width / 2, -fill.height / 2);
    if (alpha < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0, 1)));
    outline.paint(c, at);
    fill.paint(c, at);
    if (alpha < 1) c.restore();
    c.restore();
  }
}
