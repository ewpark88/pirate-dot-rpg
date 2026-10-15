import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/paint/pixel_glyphs.dart';

/// 데미지 숫자·HUD는 도트 글리프로만 그린다 → BigNum.format이 내는 모든 글자가 글리프 표에 있어야 한다
/// (없으면 빈칸: '3.4K'가 '3 4K', 10^15부터 'aa' 접미사가 통째로 사라진다).
void main() {
  test('BigNum.format이 내는 모든 글자에 3×5 글리프가 있다 (1 ~ 10^2000)', () {
    final missing = <String>{};
    for (var e = 0; e < 2000; e++) {
      for (final m in [1.0, 3.45, 12.3, 999.9]) {
        for (final ch in BigNum.fromParts(m, e).format().split('')) {
          if (!pixelGlyphs.containsKey(ch)) missing.add(ch);
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('글리프는 모두 3×5(15칸 0/1)', () {
    for (final g in pixelGlyphs.entries) {
      expect(g.value, matches(RegExp(r'^[01]{15}$')), reason: g.key);
    }
  });
}
