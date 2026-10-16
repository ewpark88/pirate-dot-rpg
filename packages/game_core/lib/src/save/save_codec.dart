import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';

/// 현재 세이브 스키마 버전. 올리면 [migrations]에 함수 + test/fixtures/saves/에 픽스처 필수.
const currentSchemaVersion = 7;

/// `migrations[i]`는 v(i+1) → v(i+2). 순수 함수만 둔다.
/// 예: `Json migrateV1ToV2(Json j) => {...j, 'schemaVersion': 2, 'newField': 0};`
const List<Json Function(Json)> migrations = [
  migrateV1ToV2,
  migrateV2ToV3,
  migrateV3ToV4,
  migrateV4ToV5,
  migrateV5ToV6,
  migrateV6ToV7,
];

/// v1 → v2: `summon.total`(누적 소환 횟수) 추가. 출시 전이라 실제 플레이어 세이브가 없어 0으로 둔다
/// → v1에서 올라온 세이브도 첫 10연 무료를 한 번 받는다 (docs/decisions/0007-save-v2-summon-total.md).
Json migrateV1ToV2(Json j) => {
  ...j,
  'schemaVersion': 2,
  'summon': {...(j['summon'] as Json), 'total': 0},
};

/// 세이브 파일이 깨졌거나 읽을 수 없을 때.
class SaveCorruptException implements Exception {
  const SaveCorruptException(this.reason);

  final String reason;

  @override
  String toString() => 'SaveCorruptException: $reason';
}

/// GameState ↔ save.json 문자열. 체크섬은 보안이 아니라 파일 손상 탐지용.
abstract final class SaveCodec {
  static String encode(GameState state) {
    final body = <String, dynamic>{'schemaVersion': currentSchemaVersion, ...state.toJson()};
    return const JsonEncoder.withIndent('  ').convert({...body, 'checksum': checksumOf(body)});
  }

  /// 검증 → 마이그레이션 → 상태. 실패하면 [SaveCorruptException].
  static GameState decode(String text) {
    final Json j;
    try {
      j = jsonDecode(text) as Json;
    } on FormatException catch (e) {
      throw SaveCorruptException('JSON 아님: ${e.message}');
    }
    final stored = j.remove('checksum');
    if (stored != checksumOf(j)) throw const SaveCorruptException('체크섬 불일치');
    try {
      return GameState.fromJson(migrate(j));
    } on Object catch (e) {
      throw SaveCorruptException('형식 오류: $e');
    }
  }

  /// 옛 버전 본문을 현재 버전까지 올린다.
  static Json migrate(Json body) {
    var j = body;
    final from = j['schemaVersion'] as int? ?? 0;
    if (from < 1 || from > currentSchemaVersion) {
      throw SaveCorruptException('지원하지 않는 schemaVersion $from');
    }
    for (var v = from; v < currentSchemaVersion; v++) {
      j = migrations[v - 1](j);
    }
    return j;
  }

  static String checksumOf(Json body) => 'sha256:${sha256.convert(utf8.encode(jsonEncode(body)))}';
}

/// 본 파일이 깨졌으면 save.bak으로 복구한다. 둘 다 없으면 null(새 게임).
Future<GameState?> loadSave(SaveStore store) async {
  final main = await store.read();
  if (main != null) {
    try {
      return SaveCodec.decode(main);
    } on SaveCorruptException {
      // 아래에서 백업 시도.
    }
  }
  final backup = await store.readBackup();
  return backup == null ? null : SaveCodec.decode(backup);
}

/// v2 → v3: 일일 퀘스트·출석 '받음' 기록, 튜토리얼 단계 (docs/decisions/0008-save-v3-meta.md).
/// 기존 세이브는 튜토리얼을 끝낸 것으로(null) 본다.
Json migrateV2ToV3(Json j) => {
  ...j,
  'schemaVersion': 3,
  'daily': {...(j['daily'] as Json), 'questsClaimed': <String>[], 'attendanceClaimed': false},
  'tutorialStep': null,
};

/// v3 → v4: 설정 `notifications`(오프라인 가득 알림, 기본 켜짐) (docs/decisions/0009-save-v4-notifications.md).
Json migrateV3ToV4(Json j) => {
  ...j,
  'schemaVersion': 4,
  'settings': {...(j['settings'] as Json), 'notifications': true},
};

/// v4 → v5: 수동 편성 `fleet`(슬롯 순서, null = 빈 칸)·`fleetInit` (docs/decisions/0010-save-v5-fleet.md).
/// 옛 세이브는 편성한 적이 없는 것으로 두고, 경제가 첫 틱에 자동 편성으로 채운다(기존 체감 유지).
Json migrateV4ToV5(Json j) => {...j, 'schemaVersion': 5, 'fleet': <String?>[], 'fleetInit': false};

/// v5 → v6: 환생 v2(docs/specs/platform-rebirth-v2.md 5절) + 현상금 자리.
/// 모은 조각 누계 = 지금 보유(쓴 적이 없으므로). 명예 외형·스킨·칭호 소급은 테이블이 필요해 경제가 첫 틱에 채운다(상자는 소급 없음).
Json migrateV5ToV6(Json j) {
  final wallet = j['wallet'] as Json;
  final progress = j['progress'] as Json;
  final ship = j['ship'] as Json;
  return {
    ...j,
    'schemaVersion': 6,
    'progress': {...progress, 'mapPiecesEarned': wallet['mapPieces'] ?? 0, 'titles': <String>[]},
    'ship': {
      ...ship,
      'honor': {'parts': <String, int>{}, 'tier': 0},
      'skin': null,
      'skinsOwned': <String>[],
      'skinChosen': false,
    },
    'rebirthShop': <String, int>{},
    'bounty': {'tickets': 3, 'refilledOn': null, 'cleared': <String, int>{}, 'progress': <String, double>{}},
  };
}

/// v6 → v7: 골드 재조정(2026-10-16, 강화 드물고 크게 — 대포·선체·화물칸 강화 1번 = 예전 3레벨)으로 그 세 부위 레벨을 3으로 나눈다(올림).
/// 옛 레벨을 새 공식에 그대로 넣으면 값이 터무니없이 커진다(화물칸 ×1e13). 돛·망루(레벨당 효과 그대로)·명예 외형(단계)은 그대로.
/// docs/decisions/0011-save-v7-part-rescale.md
const v7RescaledParts = ['cannon', 'hull', 'cargo'];
const v7LevelsPerUpgrade = 3;

Json migrateV6ToV7(Json j) {
  final ship = j['ship'] as Json;
  final parts = {...((ship['parts'] as Json?) ?? const <String, dynamic>{})};
  for (final id in v7RescaledParts) {
    final lv = parts[id] as int?;
    if (lv != null) parts[id] = (lv + v7LevelsPerUpgrade - 1) ~/ v7LevelsPerUpgrade;
  }
  return {
    ...j,
    'schemaVersion': 7,
    'ship': {...ship, 'parts': parts},
  };
}
