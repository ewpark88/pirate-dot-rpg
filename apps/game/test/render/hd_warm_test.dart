import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

import 'helpers.dart';

/// HD 미리 굽기(S5 측정 — 폰에서 보스 첫 등장 끊김): 스테이지가 바뀌면 그 해역 HD 잡몹 + 이번 보스를 줄 세우고 프레임당 한 종씩.
void main() {
  test('스테이지가 바뀌면 이번 보스·해역 잡몹을 줄 세우고 프레임당 한 종 굽는다', () {
    final regions = tables.regions;
    // HD 보스가 나오는 스테이지를 찾는다(생물 보스 29종 + 배 보스 — 거의 모든 스테이지).
    final stage = [for (var s = 1; s <= 300; s++) s].firstWhere((s) => hdBosses.containsKey(regions.bossAt(s).id));
    final hd = HdSheets()..plan(stage, regions, (k, {required boss}) => boss ? 56 : 16);
    final n = hd.queued;
    expect(n, greaterThan(0));
    hd
      ..step(2) // 첫 프레임: 콜드 스타트라 굽지 않음
      ..step(2); // 둘째 프레임: 아직(화면 몫만)
    expect(hd.queued, n, reason: '첫 두 프레임은 미리 굽기 없음(콜드 스타트)');
    hd.step(2);
    expect(hd.queued, n - 1, reason: '그 뒤 프레임당 한 종');
    expect(hd.bytes, greaterThan(0));
    hd.plan(stage, regions, (k, {required boss}) => 16);
    expect(hd.queued, n - 1, reason: '같은 스테이지면 다시 세우지 않는다');
    hd.clear();
  });

  test('저사양 칸 상한 384: 대보스 시트가 512보다 작게', () {
    final sp = hdBosses['poseidon']!;
    final big = HdSheets.bake(sp, 88, 8);
    final low = HdSheets.bake(sp, 88, 8, cap: HdSheets.lowCell);
    expect(big.cell, HdSheets.maxCell);
    expect(low.cell, HdSheets.lowCell);
    big.image.dispose();
    low.image.dispose();
  });

  test('HD v2 표정 보스는 4행(평소 2 + 예고·쓰러짐 2)으로 굽고 표정마다 다른 칸', () {
    final sp = hdBosses['sea_croc']!;
    final s = HdSheets.bake(sp, 88, 4, moods: true);
    expect(s.image.height, (s.cell * 4).toInt());
    expect(s.src(3, right: false, mood: HdMood.windup).top, s.cell * 2);
    expect(s.src(3, right: true, mood: HdMood.down).left, s.cell * 5);
    expect(s.src(3, right: false).top, 0);
    s.image.dispose();
  });
}
