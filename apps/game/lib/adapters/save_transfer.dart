import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 세이브 옮기기 코드(사용자 S1 2026-10-18 '기기 교체 시 진행을 잃는다'): 설정 화면에서 지금 세이브를 글자 코드로 내보내고,
/// 새 기기에서 붙여 넣어 가져온다. 서버 없이 — 사용자가 메모·메신저로 옮긴다(클라우드 저장은 Play Games 연동 전까지 Android 자동 백업).
///
/// 형식: `PDX1.` + base64url(gzip(세이브 JSON)). 세이브 JSON은 SaveCodec 그대로라 **체크섬·버전 마이그레이션**이 함께 온다 —
/// 글자가 하나라도 바뀌면 가져오기가 실패한다(SaveCorruptException). 공백·줄바꿈은 무시(메신저가 줄을 나눠도 된다).
abstract final class SaveTransfer {
  static const prefix = 'PDX1.';

  static String export(GameState state) => prefix + base64Url.encode(gzip.encode(utf8.encode(SaveCodec.encode(state))));

  /// [code]를 세이브로. 형식이 다르거나 깨졌으면 [SaveCorruptException].
  static GameState import(String code) {
    final text = code.replaceAll(RegExp(r'\s'), '');
    if (!text.startsWith(prefix)) throw const SaveCorruptException('not a save code');
    final List<int> raw;
    try {
      raw = gzip.decode(base64Url.decode(base64Url.normalize(text.substring(prefix.length))));
    } on FormatException {
      throw const SaveCorruptException('broken code');
    } on Object {
      throw const SaveCorruptException('broken code');
    }
    return SaveCodec.decode(utf8.decode(raw));
  }
}

/// 가져온 세이브로 게임을 바꾼다(설정 '세이브 옮기기' 화면 — S4). 앱(main.dart)이 EngineHost.replace로 덮는다. 기본 null = 숨김.
final saveImportProvider = Provider<Future<void> Function(GameState state)?>((_) => null);
