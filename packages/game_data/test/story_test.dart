import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 짧은 시나리오(story.json): 해역 보스·대보스는 고유 대사, 나머지는 첫 특성의 공용(없으면 default), 모든 보스가 대사를 받는다.
void main() {
  final t = GameTables.load();
  final s = t.story;

  test('해역 보스 6 · 대보스 6은 고유 대사(보스 1줄 + 선원 1줄)', () {
    for (final r in t.regions.regions) {
      for (final id in [r.regionBoss, ?r.wallBoss]) {
        final lines = s.bossIntro(t.regions.bosses[id]!, 0);
        expect(lines, same(s.bosses[id]), reason: id);
        expect(lines.first.who, 'boss', reason: id);
        expect(lines, hasLength(2), reason: id);
      }
    }
  });

  test('특성 보스는 첫 특성의 공용 대사, 특성 없는 보스는 default — pick으로 돌아가며', () {
    final traited = t.regions.bosses.values.firstWhere((b) => b.traits.isNotEmpty && !s.bosses.containsKey(b.id));
    final sets = s.traitLines[traited.traits.first.type]!;
    expect(s.bossIntro(traited, 0), same(sets[0]));
    expect(s.bossIntro(traited, sets.length), same(sets[0]));
    final plain = t.regions.bosses.values.firstWhere((b) => b.traits.isEmpty && !s.bosses.containsKey(b.id));
    expect(s.traitLines['default'], contains(s.bossIntro(plain, 1)));
  });

  test('모든 보스(42종)가 등장 대사를 받고, 오프닝은 5컷·한 컷 2줄 이하', () {
    for (final b in t.regions.bosses.values) {
      expect(s.bossIntro(b, 0), isNotEmpty, reason: b.id);
    }
    expect(s.opening, hasLength(5));
    expect(s.opening.every((c) => c.lines.length <= 2), isTrue);
  });
}
