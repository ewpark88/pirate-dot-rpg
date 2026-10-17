import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

import 'helpers.dart';

/// HD 굽기 비용(S1 성능 — 저사양 폰 첫 화면·메모리): 종마다 8장 × 2방향 굽기 시간과 텍스처 크기.
/// 밀도 = 단위당 기기 px(TopFrame k — 폰 4, 태블릿 5~6). 전장 크기 = 지금 도트 칸(잡몹 16·작은 것 12·보스 bossLook w).
void main() {
  final look = tables.fxMap.raw.obj('bossLook');
  double world(String kind, {required bool boss}) {
    if (!boss) return kind.endsWith('_small') ? 12 : 16;
    return look.has(kind) ? look.obj(kind).number('w') : 56;
  }

  final all = [
    for (final kind in hdEnemies.keys) (kind, false),
    for (final kind in hdBosses.keys) (kind, true),
  ];

  test('종마다 굽기 시간·텍스처 크기(측정 출력)', () {
    for (final density in const [4.0, 6.0]) {
      var totalMs = 0;
      var totalBytes = 0;
      final lines = <String>[];
      for (final (kind, boss) in all) {
        final sp = (boss ? hdBosses : hdEnemies)[kind]!;
        final sw = Stopwatch()..start();
        final sheet = HdSheets.bake(sp, world(kind, boss: boss), density);
        sw.stop();
        final bytes = sheet.image.width * sheet.image.height * 4;
        sheet.image.dispose();
        totalMs += sw.elapsedMilliseconds;
        totalBytes += bytes;
        lines.add('${boss ? 'B' : 'E'} $kind ${sw.elapsedMilliseconds}ms ${(bytes / 1048576).toStringAsFixed(2)}MB');
      }
      // 측정값은 실패 때만 보인다(통과하면 조용히) — 다시 재려면 이 시험을 일부러 실패시켜 본다.
      printOnFailure(
        '밀도 $density: 종 ${all.length} · 굽기 합 ${totalMs}ms · 텍스처 합 ${(totalBytes / 1048576).toStringAsFixed(1)}MB\n'
        '${lines.join('\n')}',
      );
      expect(totalBytes, greaterThan(0));
    }
  });

  test('캐시는 바이트 상한을 넘지 않는다 — 전부 차례로 보여도(태블릿 밀도) 오래 안 쓴 것부터 버림', () {
    final sheets = HdSheets();
    var largest = 0;
    for (final (kind, boss) in all) {
      final s = sheets.sheet(
        kind,
        boss: boss,
        world: world(kind, boss: boss),
        density: 6,
      )!;
      final b = s.image.width * s.image.height * 4;
      if (b > largest) largest = b;
      expect(sheets.bytes, lessThanOrEqualTo(sheets.budget + largest), reason: kind);
    }
    // 방금 쓴 것은 남는다.
    final (lastKind, lastBoss) = all.last;
    expect(
      sheets.sheet(
        lastKind,
        boss: lastBoss,
        world: world(lastKind, boss: lastBoss),
        density: 6,
      ),
      isNotNull,
    );
    sheets.clear();
    expect(sheets.bytes, 0);
  });

  test('상한은 화면 크기 비례 — 폰(밀도 4 이하) 48MB · 태블릿(밀도 6) 96MB · 그 사이는 밀도²', () {
    double budgetAt(double density) {
      final sheets = HdSheets()..sheet(all.first.$1, boss: all.first.$2, world: 16, density: density);
      final mb = sheets.budget / 1048576;
      sheets.clear();
      return mb;
    }

    expect(budgetAt(3), 48);
    expect(budgetAt(4), 48);
    expect(budgetAt(5), closeTo(48 * 25 / 16, 0.01));
    expect(budgetAt(6), 96);
    expect(budgetAt(8), 96);
  });
}
