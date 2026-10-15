import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

/// 과거 모든 버전의 세이브 픽스처. 스키마를 올리면 새 버전 파일을 추가하고, 옛 파일은 지우지 않는다.
/// 갱신은 사람이: `dart run game_cli fixtures --saves`
List<File> saveFixtures() =>
    Directory('test/fixtures/saves').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

void main() {
  final sample = GameState.newGame(playerId: 'p1', seed: 7, now: DateTime.utc(2026, 11));

  test('픽스처가 버전마다 하나씩 있다 (v1 ~ 현재)', () {
    final names = saveFixtures().map((f) => f.uri.pathSegments.last).toSet();
    for (var v = 1; v <= currentSchemaVersion; v++) {
      expect(names, contains('v$v.json'), reason: '스키마 v$v 픽스처가 없습니다 — 마이그레이션과 함께 추가하세요');
    }
  });

  test('모든 과거 버전 픽스처를 현재 버전으로 불러온다', () {
    for (final f in saveFixtures()) {
      final state = SaveCodec.decode(f.readAsStringSync());
      expect(state.playerId, isNotEmpty, reason: f.path);
    }
  });

  test('직렬화 왕복', () {
    final mid = SaveCodec.decode(File('test/fixtures/saves/v1.json').readAsStringSync());
    final again = SaveCodec.decode(SaveCodec.encode(mid));
    expect(again.toJson(), mid.toJson());
    expect(mid.wallet.gold, BigNum.parse('1.25e6'));
    expect(mid.crews['manta']!.level, 46);
  });

  test('v1 → v2: summon.total이 0으로 생긴다 (첫 10연 무료 대상)', () {
    final v1 = SaveCodec.decode(File('test/fixtures/saves/v1.json').readAsStringSync());
    expect(v1.summonsTotal, 0);
    expect(v1.pityCount, isNonNegative);
    final v2 = SaveCodec.decode(File('test/fixtures/saves/v2.json').readAsStringSync());
    expect(v2.toJson()['summon'], containsPair('total', v2.summonsTotal));
  });

  test('v2 → v3: 일일 받음 기록이 비고, 튜토리얼은 끝난 것(null)', () {
    final v2 = SaveCodec.decode(File('test/fixtures/saves/v2.json').readAsStringSync());
    expect(v2.daily.questsClaimed, isEmpty);
    expect(v2.daily.attendanceClaimed, isFalse);
    expect(v2.tutorialStep, isNull);
    expect(GameState.newGame(playerId: 'n', seed: 1, now: DateTime.utc(2026, 11)).tutorialStep, 1);
  });

  test('v3 → v4: 알림 설정이 켜짐(true)으로 생기고, 설정 명령으로 끌 수 있다', () {
    final v3 = SaveCodec.decode(File('test/fixtures/saves/v3.json').readAsStringSync());
    expect(v3.settings.notifications, isTrue);
    expect(v3.settings.withValue('notifications', false).notifications, isFalse);
    final v4 = SaveCodec.decode(File('test/fixtures/saves/v4.json').readAsStringSync());
    expect(v4.toJson()['settings'], containsPair('notifications', v4.settings.notifications));
  });

  test('v4 → v5: 편성이 비고 fleetInit false(첫 틱에 자동 편성), v5는 빈 칸(null)까지 왕복', () {
    final v4 = SaveCodec.decode(File('test/fixtures/saves/v4.json').readAsStringSync());
    expect(v4.fleet, isEmpty);
    expect(v4.fleetInit, isFalse);
    final v5 = SaveCodec.decode(File('test/fixtures/saves/v5.json').readAsStringSync());
    expect(v5.fleetInit, isTrue);
    expect(v5.fleet, contains(null));
    expect(SaveCodec.decode(SaveCodec.encode(v5)).fleet, v5.fleet);
  });

  test('본문을 고치면 체크섬이 깨진다', () {
    final text = SaveCodec.encode(sample).replaceFirst('"gems": 0', '"gems": 999');
    expect(() => SaveCodec.decode(text), throwsA(isA<SaveCorruptException>()));
  });

  test('모르는 미래 버전은 거부', () {
    final j = jsonDecode(SaveCodec.encode(sample)) as Map<String, dynamic>
      ..remove('checksum')
      ..['schemaVersion'] = currentSchemaVersion + 1;
    j['checksum'] = SaveCodec.checksumOf(j);
    expect(() => SaveCodec.decode(jsonEncode(j)), throwsA(isA<SaveCorruptException>()));
  });

  group('loadSave', () {
    test('본 파일이 깨지면 save.bak으로 복구', () async {
      final store = MemorySaveStore(main: '{깨진', backup: SaveCodec.encode(sample));
      expect((await loadSave(store))!.playerId, 'p1');
    });

    test('둘 다 없으면 새 게임(null)', () async {
      expect(await loadSave(MemorySaveStore()), isNull);
    });

    test('쓰면 이전 본이 백업으로 간다', () async {
      final store = MemorySaveStore();
      await store.write('a');
      await store.write('b');
      expect((store.main, store.backup), ('b', 'a'));
    });
  });
}
