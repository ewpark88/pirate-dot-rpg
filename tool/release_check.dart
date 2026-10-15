// 배포 빌드 운영자 코드 잔존 검사 (요청서 platform-release-check). 의존성 없음(dart:io만).
// 사용: dart run tool/release_check.dart [--skip-build] [--marker <문자열>]
//   1) appbundle(release, OPERATOR 없음) → base/lib/arm64-v8a/libapp.so에 표식이 **없어야** 한다.
//   2) apk(release, OPERATOR=true, arm64) → lib/arm64-v8a/libapp.so에 표식이 **있어야** 한다(검사가 작동한다는 양성 대조).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const defaultMarker = '__OPERATOR_PANEL__';

Future<void> main(List<String> args) async {
  final skipBuild = args.contains('--skip-build');
  final mi = args.indexOf('--marker');
  final marker = mi >= 0 ? args[mi + 1] : defaultMarker;
  final app = Directory('apps/game');
  const aab = 'build/app/outputs/bundle/release/app-release.aab';
  const opApk = 'build/app/outputs/flutter-apk/app-release.apk';

  if (!skipBuild) {
    await _flutter(app, ['build', 'appbundle', '--release', '--obfuscate', '--split-debug-info=build/symbols']);
  }
  final storeHits = _count(_entry(File('${app.path}/$aab'), 'base/lib/arm64-v8a/libapp.so'), marker);

  if (!skipBuild) {
    // 운영자 apk는 같은 출력 경로를 쓰므로 appbundle 검사 뒤에 만든다.
    await _flutter(app, [
      'build',
      'apk',
      '--release',
      '--dart-define=OPERATOR=true',
      '--target-platform',
      'android-arm64',
    ]);
  }
  final opHits = _count(_entry(File('${app.path}/$opApk'), 'lib/arm64-v8a/libapp.so'), marker);

  stdout.writeln('표식 "$marker": 배포 aab $storeHits회 · 운영자 apk $opHits회');
  if (opHits == 0) {
    stderr.writeln('✗ 운영자 빌드에도 표식이 없다 — 검사가 작동하지 않는다(표식 상수가 지워졌거나 참조되지 않음).');
    exit(1);
  }
  if (storeHits > 0) {
    stderr.writeln('✗ 배포 빌드에 운영자 코드가 남았다 — `if (kOperator)` 밖에서 operator/를 부르는 곳을 찾으세요.');
    exit(1);
  }
  stdout
    ..writeln('✓ 배포 빌드에 운영자 코드 없음')
    ..writeln(
      '다음: 기기 연결 시 `python -I -B docs/store/device/release_smoke.py` (release apk 실행 확인 — 빌드 검사로는 실행 중 크래시를 못 잡는다)',
    );
}

Future<void> _flutter(Directory dir, List<String> args) async {
  stdout.writeln('> flutter ${args.join(' ')}');
  final p = await Process.start(
    'flutter',
    args,
    workingDirectory: dir.path,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await p.exitCode != 0) {
    stderr.writeln('✗ 빌드 실패');
    exit(1);
  }
}

/// zip(aab·apk)에서 파일 하나를 꺼낸다. 중앙 디렉터리를 읽고 stored(0)·deflate(8)만 지원.
Uint8List _entry(File zip, String name) {
  if (!zip.existsSync()) {
    stderr.writeln('✗ ${zip.path} 없음 (--skip-build면 먼저 빌드하세요)');
    exit(1);
  }
  final b = zip.readAsBytesSync();
  final d = ByteData.sublistView(b);
  var eocd = b.length - 22;
  while (eocd >= 0 && d.getUint32(eocd, Endian.little) != 0x06054b50) {
    eocd--;
  }
  final count = d.getUint16(eocd + 10, Endian.little);
  var p = d.getUint32(eocd + 16, Endian.little);
  for (var i = 0; i < count; i++) {
    final method = d.getUint16(p + 10, Endian.little);
    final size = d.getUint32(p + 20, Endian.little);
    final nameLen = d.getUint16(p + 28, Endian.little);
    final extraLen = d.getUint16(p + 30, Endian.little);
    final commentLen = d.getUint16(p + 32, Endian.little);
    final local = d.getUint32(p + 42, Endian.little);
    final entryName = utf8.decode(b.sublist(p + 46, p + 46 + nameLen));
    if (entryName == name) {
      final start = local + 30 + d.getUint16(local + 26, Endian.little) + d.getUint16(local + 28, Endian.little);
      final data = b.sublist(start, start + size);
      return switch (method) {
        0 => data,
        8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(data)),
        _ => throw StateError('지원하지 않는 압축 $method'),
      };
    }
    p += 46 + nameLen + extraLen + commentLen;
  }
  stderr.writeln('✗ ${zip.path}에 $name 없음');
  exit(1);
}

int _count(Uint8List hay, String marker) {
  final m = utf8.encode(marker);
  var n = 0;
  outer:
  for (var i = 0; i <= hay.length - m.length; i++) {
    for (var j = 0; j < m.length; j++) {
      if (hay[i + j] != m[j]) continue outer;
    }
    n++;
  }
  return n;
}
