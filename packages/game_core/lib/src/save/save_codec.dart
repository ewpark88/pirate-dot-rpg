import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';

/// 현재 세이브 스키마 버전. 올리면 [migrations]에 함수 + test/fixtures/saves/에 픽스처 필수.
const currentSchemaVersion = 2;

/// `migrations[i]`는 v(i+1) → v(i+2). 순수 함수만 둔다.
/// 예: `Json migrateV1ToV2(Json j) => {...j, 'schemaVersion': 2, 'newField': 0};`
const List<Json Function(Json)> migrations = [migrateV1ToV2];

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
