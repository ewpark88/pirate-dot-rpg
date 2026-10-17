import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:game_core/game_core.dart';
import 'package:path/path.dart' as p;
import 'package:pirate_dot/adapters/analytics/non_fatal.dart';

/// 마지막 저장이 실패한 이유. 다음 저장이 성공하면 null로 돌아간다.
enum SaveFailure { diskFull, io }

/// 파일 세이브 저장소 (설계서 5.2, 스펙 platform-save). 원자적 쓰기: `save.tmp`에 쓰고 → `save.bak`을 `save.bak2`로,
/// `save.json`을 `save.bak`으로 → `save.tmp`를 `save.json`으로 바꾼다. 쓰는 도중 앱이 죽어도 셋 중 하나는 온전하다.
/// [write]는 던지지 않는다 — 실패는 [failure]로 알린다(엔진의 저장 줄이 한 번의 실패로 막히지 않게).
class FileSaveStore implements SaveStore {
  FileSaveStore(
    this.dir, {
    @visibleForTesting Future<void> Function(File file, String text)? writer,
    @visibleForTesting Future<void> Function(Duration wait)? delay,
  }) : _writer = writer ?? _writeFlush,
       _delay = delay ?? Future<void>.delayed;

  /// 일시 실패 재시도 사이 대기 (시도 = 이 길이 + 1).
  static const _retryWaits = [Duration(milliseconds: 50), Duration(milliseconds: 200)];

  /// 디스크 가득: Android·Linux ENOSPC 28, Windows ERROR_DISK_FULL 112 · ERROR_HANDLE_DISK_FULL 39.
  static const _diskFullCodes = {28, 112, 39};

  final Directory dir;
  final Future<void> Function(File, String) _writer;
  final Future<void> Function(Duration) _delay;
  final _failure = ValueNotifier<SaveFailure?>(null);

  /// 마지막 저장의 실패 이유. UI가 "저장 공간 부족" 등을 보여 줄 때 듣는다.
  ValueListenable<SaveFailure?> get failure => _failure;

  File get _main => File(p.join(dir.path, 'save.json'));
  File get _backup => File(p.join(dir.path, 'save.bak'));
  File get _backup2 => File(p.join(dir.path, 'save.bak2'));
  File get _tmp => File(p.join(dir.path, 'save.tmp'));

  @override
  Future<String?> read() => _readOrNull(_main);

  /// `save.bak`이 없거나 깨졌으면 `save.bak2`. 둘 다 없으면 `save.bak` 원문(→ `loadSave`가 깨짐을 알린다).
  @override
  Future<String?> readBackup() async {
    final bak = await _readOrNull(_backup);
    if (bak != null && _decodes(bak)) return bak;
    return await _readOrNull(_backup2) ?? bak;
  }

  @override
  Future<void> write(String json) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _writeOnce(json);
        _failure.value = null;
        return;
      } on FileSystemException catch (e) {
        if (_diskFullCodes.contains(e.osError?.errorCode)) {
          await _deleteTmp();
          return _fail(SaveFailure.diskFull, e);
        }
        if (attempt >= _retryWaits.length) {
          await _deleteTmp();
          return _fail(SaveFailure.io, e);
        }
        await _delay(_retryWaits[attempt]);
      } on Object catch (e) {
        return _fail(SaveFailure.io, e);
      }
    }
  }

  Future<void> _writeOnce(String json) async {
    await dir.create(recursive: true);
    await _writer(_tmp, json);
    if (_backup.existsSync()) {
      if (_backup2.existsSync()) await _backup2.delete();
      await _backup.rename(_backup2.path);
    }
    if (_main.existsSync()) await _main.rename(_backup.path);
    await _tmp.rename(_main.path);
  }

  void _fail(SaveFailure f, Object e) {
    reportNonFatal(e, StackTrace.current, 'save: ${f.name}');
    _failure.value = f;
  }

  Future<void> _deleteTmp() async {
    try {
      if (_tmp.existsSync()) await _tmp.delete();
    } on Object {
      // 지우기도 실패하면 다음 저장이 덮어쓴다.
    }
  }

  static bool _decodes(String text) {
    try {
      SaveCodec.decode(text);
      return true;
    } on Object {
      return false;
    }
  }

  static Future<void> _writeFlush(File f, String text) => f.writeAsString(text, flush: true);

  static Future<String?> _readOrNull(File f) async => f.existsSync() ? f.readAsString() : null;
}
