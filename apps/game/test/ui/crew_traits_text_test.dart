import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/crew/crew_text.dart';

// 선원 특성 중복 정리(S2 crew-traits, 사용자 2026-10-17 '겹치면 스스로 찾아 바꿔라') 문구 — 값은 skills.json legends에서.

void main() {
  final t = GameTables.load();
  final legendIdx = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  final mythicIdx = t.rarities.rarities.indexWhere((r) => r.id == 'mythic');

  Future<List<String>> lines(String crew, int rarity, String lang) async {
    final l = await AppLocalizations.delegate.load(Locale(lang));
    return legendLines(l, t.skills.legendFor(crew, rarity, legendIdx)!, rarity: rarity);
  }

  test('pelly 연쇄 번개: 등급별 이어지는 수(전설 5 · 신화 7)와 튈 때마다 70%', () async {
    expect(await lines('pelly', legendIdx, 'ko'), contains('연쇄 번개: 적 5마리까지 이어짐 (튈 때마다 피해 70%)'));
    expect(
      await lines('pelly', mythicIdx, 'en'),
      contains('Chain lightning: jumps to up to 7 enemies (70% damage per jump)'),
    );
  });

  test('bones 처형 · volt 충전 사격 · polly 추적 깃털 (신화는 mythic 값)', () async {
    expect(await lines('bones', legendIdx, 'ko'), contains('처형: 체력 30% 아래 적에게 피해 ×2'));
    expect(await lines('bones', mythicIdx, 'ko'), contains('처형: 체력 40% 아래 적에게 피해 ×2.5'));
    expect(await lines('volt', legendIdx, 'ko'), contains('충전 사격: 5번째 사격마다 피해 ×2 + 기절 0.6초'));
    expect(await lines('volt', mythicIdx, 'en'), contains('Charged shot: every 4th shot deals ×2.5 and stuns 0.8s'));
    expect(await lines('polly', legendIdx, 'ko'), contains('추적 깃털: 빗나가지 않음 (회피하는 보스에 강함)'));
  });

  test('도감 필터 명중: polly는 추적(안 빗나감)', () {
    expect(crewIdentity(t, 'polly')!.hit, HitKind.homing);
    expect(crewIdentity(t, 'octo')!.hit, isNot(HitKind.homing));
  });
}
