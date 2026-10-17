import 'dart:convert';
import 'dart:io';

import 'package:game_core/src/economy/dex.dart' show dexCatalog;
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 도감 v2 보스 42종 초안(docs/specs/platform-bestiary-v2-regions.draft.json)을 지금 표에 덧대 본다.
/// 초안이 regions.json에 들어가면(S2 수치·S3 그림 id 뒤) 이 테스트는 지운다.
void main() {
  final draft =
      jsonDecode(File('../../docs/specs/platform-bestiary-v2-regions.draft.json').readAsStringSync())
          as Map<String, dynamic>;

  GameTables applied() {
    final raw = Map<String, String>.of(rawTables);
    final r = jsonDecode(raw['regions']!) as Map<String, dynamic>;
    r['wallEvery'] = draft['wallEvery'];
    final byId = (draft['regions'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();
    for (final region in (r['regions'] as List).cast<Map<String, dynamic>>()) {
      region.addAll(byId[region['id']]!);
    }
    (r['bosses'] as List).addAll(draft['bosses'] as List);
    raw['regions'] = jsonEncode(r);
    return GameTables.load(raw);
  }

  test('덧대면 표가 읽히고 검사를 통과한다 · 보스 42종(해역마다 7) · 이름 ko/en', () {
    final t = applied();
    expect(t.regions.validate(), isEmpty);
    expect(t.regions.bosses, hasLength(42));
    final catalog = dexCatalog(t);
    expect(catalog.values.where((b) => b), hasLength(42));
    for (final r in t.regions.regions) {
      expect({r.midBoss, r.regionBoss, ...r.bossRotation, r.wallBoss}, hasLength(7), reason: r.id);
    }
    final names = (draft['names'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();
    for (final b in draft['bosses'] as List) {
      expect(names[(b as Map)['nameKey']]?.keys, containsAll(['ko', 'en']), reason: '${b['id']}');
    }
  });

  test('수용 기준 1: 해역마다 연속 10스테이지에 보스 4종 이상, 10단위 = 대보스, 25·50은 그대로', () {
    final t = applied();
    final per = t.regions.stagesPerRegion;
    for (final r in t.regions.regions) {
      final from = r.fromStage;
      for (var s = from; s + 9 < from + per; s++) {
        expect({for (var k = s; k < s + 10; k++) t.regions.bossAt(k).id}.length, greaterThanOrEqualTo(4));
      }
      for (var s = from; s < from + per; s++) {
        final id = t.regions.bossAt(s).id;
        if (s % per == 0) {
          expect(id, r.regionBoss);
        } else if (s % t.regions.midBossEvery == 0) {
          expect(id, r.midBoss);
        } else if (s % 10 == 0) {
          expect(id, r.wallBoss, reason: '$s');
        }
      }
    }
  });
}
