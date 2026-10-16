import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// UI가 쓰는 crewAttack은 개성 aim·등급 템포를 반영한다 (rarityTempo: 전설 ×0.9·신화 ×0.8 간격).
void main() {
  final t = EconomyHarness.tables;

  test('crewAttack: 일반은 aim 간격 그대로, 신화는 rarityTempo만큼 빠름', () {
    final aim = t.crews.byId('octo').aim!.number('intervalSec');
    expect(crewAttack(t, 'octo', 0).intervalSec, closeTo(aim, 1e-9));
    final mythic = t.rarities.rarities.indexWhere((r) => r.id == 'mythic');
    expect(crewAttack(t, 'octo', mythic).intervalSec, closeTo(aim * t.skills.rarityTempo[mythic], 1e-9));
  });
}
