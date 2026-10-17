import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

import 'helpers.dart';

/// HD 캐시 메모리(S5 실기기 PSS 638MB → 목표 500MB 이하): 상한·지난 보스 해제·버릴 대기 비우기·장면 버릴 때 해제·lite 찡긋 행 생략.
void main() {
  test('잡몹 27종 + 보스 전부 구워도 캐시는 상한(폰 48MB) 안', () {
    final s = HdSheets();
    for (final k in hdEnemies.keys) {
      s.sheet(k, boss: false, world: 24 * HdSheets.enemyBoost, density: 4);
    }
    for (final k in hdBosses.keys) {
      s.sheet(k, boss: true, world: 88, density: 4);
      expect(s.bytes, lessThanOrEqualTo(s.budget));
    }
    expect(s.budget, HdSheets.budgetBytes);
    s.dispose();
  });

  test('밀려난 시트는 적이 없어도(sheet 호출 없이) 20프레임 뒤 버려진다 · dispose는 바로 0', () {
    final s = HdSheets();
    for (final k in hdBosses.keys.take(12)) {
      s.sheet(k, boss: true, world: 88, density: 4);
    }
    expect(s.retiredBytes, greaterThan(0), reason: '상한을 넘어 몇 장은 밀려났다');
    for (var i = 0; i < 21; i++) {
      s.step(4);
    }
    expect(s.retiredBytes, 0);
    s
      ..sheet('crab', boss: false, world: 31, density: 4)
      ..dispose();
    expect((s.bytes, s.retiredBytes), (0, 0));
  });

  test('스테이지가 바뀌면 이번 보스 말고 지난 보스 시트는 버린다', () {
    final s = HdSheets();
    final regions = tables.regions;
    final old = regions.bossAt(10).id;
    s.sheet(old, boss: true, world: 88, density: 4);
    final before = s.bytes;
    final next = [for (var st = 11; st < 300; st++) regions.bossAt(st).id].firstWhere((id) => id != old);
    final st = [for (var st = 11; st < 300; st++) st].firstWhere((x) => regions.bossAt(x).id == next);
    s.plan(st, regions, (k, {required boss}) => 30);
    expect(s.bytes, lessThan(before));
    expect(s.report(), isNot(contains('b:$old')));
    s.dispose();
  });

  test('저사양(lite 칸 상한)이면 잡몹 찡긋 행을 안 굽는다(시트 절반)', () {
    final s = HdSheets()..cap = HdSheets.lowCell;
    final lite = s.sheet('crab', boss: false, world: 31, density: 4)!;
    s.cap = HdSheets.maxCell;
    final full = s.sheet('crab', boss: false, world: 31, density: 4)!;
    expect((lite.hits, full.hits), (false, true));
    expect(lite.image.height * 2, full.image.height);
    s.dispose();
  });

  test('작은 장면(선원 미리보기)은 상한 12MB·낮은 칸·찡긋 행 없음', () {
    final s = HdSheets()..small = true;
    for (final k in hdBosses.keys.take(6)) {
      s.sheet(k, boss: true, world: 88, density: 4);
    }
    expect(s.budget, HdSheets.smallBudgetBytes);
    expect(s.bytes, lessThanOrEqualTo(HdSheets.smallBudgetBytes));
    expect(s.sheet('crab', boss: false, world: 31, density: 4)!.hits, isFalse);
    s.dispose();
  });
}
