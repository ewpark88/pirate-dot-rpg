import 'dart:io';

import 'package:game_core/contracts.dart';
import 'package:path/path.dart' as p;

/// 파일 세이브 저장소 (설계서 5.2). 원자적 쓰기: `save.tmp`에 쓰고 → 기존 `save.json`을 `save.bak`으로 →
/// `save.tmp`를 `save.json`으로 바꾼다. 쓰는 도중 앱이 죽어도 `save.json` 또는 `save.bak` 하나는 온전하다.
class FileSaveStore implements SaveStore {
  FileSaveStore(this.dir);

  final Directory dir;

  File get _main => File(p.join(dir.path, 'save.json'));
  File get _backup => File(p.join(dir.path, 'save.bak'));
  File get _tmp => File(p.join(dir.path, 'save.tmp'));

  @override
  Future<String?> read() => _readOrNull(_main);

  @override
  Future<String?> readBackup() => _readOrNull(_backup);

  @override
  Future<void> write(String json) async {
    await dir.create(recursive: true);
    await _tmp.writeAsString(json, flush: true);
    if (_main.existsSync()) {
      if (_backup.existsSync()) await _backup.delete();
      await _main.rename(_backup.path);
    }
    await _tmp.rename(_main.path);
  }

  static Future<String?> _readOrNull(File f) async => f.existsSync() ? f.readAsString() : null;
}
