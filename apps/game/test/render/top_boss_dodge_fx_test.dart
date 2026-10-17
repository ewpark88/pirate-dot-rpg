import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_boss_pattern.dart';

/// 보스 공격 예고(회피 boss-dodge, S1): 조준 고정 자리에 장판, homing이면 배에 조준 표시, 빗나감은 MISS!.
Future<Color> _px(void Function(Canvas c) draw, Offset at) async {
  final rec = PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(200, 200);
  final data = (await img.toByteData())!;
  final i = (at.dy.round() * 200 + at.dx.round()) * 4;
  img.dispose();
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  test('폭발 장판은 예고 시작 때 고정한 조준 자리에(배가 비켜도 따라가지 않음)', () async {
    final p = TopBossPattern()..warn(1, 'blast', 100, 20, 0, 1, 20, 0, 1000, aim: const Offset(60, 150));
    // 배는 비켜서 (140,150). 장판 테두리는 조준 (60,150) 둘레 반지름 20.
    final at = await _px(
      (c) => p.paint(c, 500, const Offset(140, 150), (_) => null, flash: false),
      const Offset(80, 150),
    );
    expect(at.r, greaterThan(0.8), reason: '조준 자리 장판 테두리가 붉다');
    final ship = await _px(
      (c) => p.paint(c, 500, const Offset(140, 150), (_) => null, flash: false),
      const Offset(160, 150),
    );
    expect(ship.a, lessThan(0.05), reason: '비켜선 배 둘레엔 장판 없음');
  });

  test('homing(피할 수 없음)이면 배에 붉은 조준 고리, 아니면 없음', () async {
    for (final homing in [true, false]) {
      final p = TopBossPattern()
        ..warn(1, 'volley', 100, 20, 0, 3, 0, 0, 1000, aim: const Offset(100, 150), homing: homing);
      // 배 (40,150), 조준 고리 반지름 26 - 6*0.5 = 23 → (63,150)
      final c = await _px(
        (c) => p.paint(c, 500, const Offset(40, 150), (_) => null, flash: false),
        const Offset(40, 127),
      );
      expect(c.a > 0.3, homing, reason: 'homing=$homing');
    }
  });

  test('빗나감 MISS!: 그리고 0.8초 뒤 지워도 문제없다', () {
    final p = TopBossPattern()..miss(const Offset(50, 50), 0);
    final rec = PictureRecorder();
    final c = Canvas(rec);
    p.paint(c, 400, const Offset(50, 50), (_) => null, flash: false);
    p.paint(c, 900, const Offset(50, 50), (_) => null, flash: false);
    rec.endRecording().dispose();
  });
}
