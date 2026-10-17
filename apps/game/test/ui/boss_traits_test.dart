import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';

// 보스 특성 UI (#25): 특성 이름·수치 + 카운터 계열 한 줄, 약점 = 표 약점 + 특성 카운터.

void main() {
  final t = GameTables.load();

  testWidgets('한 줄 요약: 회피 25% · 카운터 계열(최대 3개)에 약함 / 특성 없는 보스는 빈 글', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            l = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    final evade = t.regions.bosses['storm_pirate']!;
    final line = traitSummary(l, t, evade);
    expect(line, startsWith('회피 25%'));
    expect(line, endsWith('에 약함'));
    expect('·'.allMatches(line.split(' · ').last).length, lessThanOrEqualTo(2));
    final plain = t.regions.bosses.values.firstWhere((b) => b.traits.isEmpty && b.weakFamilies.isEmpty);
    expect(traitSummary(l, t, plain), isEmpty);
    for (final b in t.regions.bosses.values) {
      expect(bossCounters(b).toSet(), {...b.weakFamilies, ...b.counterFamilies});
      for (final tr in b.traits) {
        expect(traitName(l, tr), isNotEmpty, reason: '${b.id} ${tr.type}');
      }
    }
  });
}
