import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/hud/boss_cutin_name.dart';

// 해역 보스 컷인 위 이름: 가로는 컷인과 같이 (들어옴 300ms 오른쪽에서 · 머묾 600ms · 빠짐 300ms 왼쪽으로, S3 fx_map).

void main() {
  test('컷인 가로 밀림: 시작은 화면 폭만큼 오른쪽 → 300ms에 제자리 → 머묾 → 끝에 왼쪽으로 화면 폭', () {
    expect(cutInShift(0, 400), 400);
    expect(cutInShift(150, 400), 200);
    expect(cutInShift(300, 400), 0);
    expect(cutInShift(800, 400), 0);
    expect(cutInShift(1050, 400), -200);
    expect(cutInShift(1200, 400), -400);
    expect(cutInShift(1500, 400), -400);
  });
}
