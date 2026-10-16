import 'dart:convert';

import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  group('심은 테이블', () {
    test('불러오고 검증을 통과한다', () {
      final t = GameTables.load();
      expect(t.crews.crews, hasLength(40));
      expect(t.shipParts.parts.map((p) => p.id), shipPartIds);
    });

    test('한 파 마리 수 = min(14, 6 + floor(stage/10)) = 총량 기준 pool, 탑다운은 무리 32 + floor(stage/2) 최대 150', () {
      final w = GameTables.load().waves;
      expect(w.mobCountAt(1), 6);
      expect(w.mobCountAt(37), 9);
      expect(w.mobCountAt(500), 14);
      expect(w.mobPoolAt(37), 9);
      expect(w.topMobCountAt(1), 32);
      expect(w.topMobCountAt(9999), 150);
    });

    test('배 등급은 스테이지로 정해진다', () {
      final s = GameTables.load().shipTiers;
      expect(s.tierAt(1).id, 'dinghy');
      expect(s.tierAt(30).id, 'sloop');
      expect(s.tierAt(149).id, 'warship');
      expect(s.tierAt(999).id, 'ghost');
    });
  });

  group('검증기는 틀린 값을 잡는다', () {
    Map<String, String> patched(String table, void Function(Map<String, dynamic>) edit) {
      final m = jsonDecode(rawTables[table]!) as Map<String, dynamic>;
      edit(m);
      return {...rawTables, table: jsonEncode(m)};
    }

    test('소환 확률 합 ≠ 1.0', () {
      final raw = patched('rarities', (m) => ((m['rarities'] as List).first as Map)['summonRate'] = 0.58);
      expect(
        () => GameTables.load(raw),
        throwsA(isA<TableValidationException>().having((e) => e.errors.join(), 'errors', contains('확률 합'))),
      );
    });

    test('비용 증가율 ≤ 1', () {
      final raw = patched('ship_parts', (m) => ((m['parts'] as List).first as Map)['costGrowth'] = 1.0);
      expect(() => GameTables.load(raw), throwsA(isA<TableValidationException>()));
    });

    test('없는 계열을 참조하는 선원', () {
      final raw = patched('crews', (m) => ((m['crews'] as List).first as Map)['family'] = 'no_such_family');
      expect(() => GameTables.load(raw), throwsA(isA<TableValidationException>()));
    });

    test('타입이 틀리면 경로를 알려준다', () {
      final raw = patched('waves', (m) => m['tickMs'] = 'fifty');
      expect(
        () => GameTables.load(raw),
        throwsA(isA<TableFormatException>().having((e) => e.path, 'path', 'waves.tickMs')),
      );
    });

    test('일일 퀘스트 5개는 피로 금지 규칙 위반', () {
      final raw = patched('meta', (m) => (m['dailyQuests'] as List).add({'id': 'x', 'type': 'kill', 'target': 1}));
      expect(() => GameTables.load(raw), throwsA(isA<TableValidationException>()));
    });
  });
}
