import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

void main() {
  final tables = GameTables.load();
  final keys = [
    for (final c in tables.crews.crews) c.nameKey,
    for (final r in tables.rarities.rarities) r.nameKey,
    for (final p in tables.shipParts.parts) p.nameKey,
    for (final t in tables.shipTiers.tiers) t.nameKey,
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.languageCode}: 화면에 쓰는 테이블 nameKey는 모두 문구가 있다', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final k in keys) {
        expect(tableText(l10n, k), isNotEmpty, reason: k);
      }
    });
  }

  test('없는 키는 바로 실패한다', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(() => tableText(l10n, 'nope'), throwsArgumentError);
  });
}
