import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_muzzle.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD 발사 빛: 쏜 적만, 0.25초 동안, 쏘는 부위(왼쪽 보기 기준 muzzle — 오른쪽 보면 x 뒤집기)에서.
void main() {
  test('쏜 갈매기만 부리 자리에서 0.25초 번쩍', () {
    final gull = hdEnemies['gull']!;
    expect(gull.muzzle, isNotNull, reason: 'S5 muzzle 자리');
    final m = HdMuzzle()..fired(7, 1000);
    final rec = PictureRecorder();
    final c = Canvas(rec);
    m
      ..collect(7, 'gull', 100, 50, 16, right: false, now: 1100)
      ..collect(8, 'gull', 0, 0, 16, right: false, now: 1100) // 안 쏜 적
      ..collect(7, 'gull', 100, 50, 16, right: false, now: 1300); // 0.25초 지남
    expect(m.pending, 1);
    m.paint(c);
    expect(m.pending, 0);
    rec.endRecording().dispose();
    // 자리 계산은 공개 규칙과 같다: x = 100 + muzzle.dx · 16 / (2·extent)
    final r = 16 / (2 * gull.extent);
    expect(100 + gull.muzzle!.dx * r, lessThan(100), reason: '왼쪽 보기면 부리는 왼쪽');
  });
}
