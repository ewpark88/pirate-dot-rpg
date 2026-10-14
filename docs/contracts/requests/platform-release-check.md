# platform: 배포 빌드 운영자 코드 잔존 검사 (`tool/check --release`)

- 요청 레인 / 날짜: platform(S5) / 2026-10-14 · 스펙 `docs/specs/platform-m4.md` e.3 (S1 승인)
- 바꿀 경로: `apps/game/lib/operator/`(표식 상수), `tool/`(검사 단계) — 둘 다 platform 밖

## 왜 필요한가
지금은 소스에서 `if (kOperator)` 가드만 검사한다. 실제 aab에 운영자 코드가 남았는지는 아무도 안 본다(PROGRESS 남은 문제).

## 제안
1. `operator/` 패널 코드 안(가드 안에서만 도달하는 곳)에 고유 문자열을 실제로 쓰는 상수 하나:
   ```dart
   const operatorMarker = '__OPERATOR_PANEL__'; // 배포 빌드 검사용 표식 — 지우지 말 것 (tool/check --release)
   ```
   (트리 셰이킹으로 사라지려면 kOperator=false일 때 도달 불가해야 하고, true일 때는 반드시 참조돼야 한다 — 예: 패널 제목 위젯의 `Key`.)
2. `tool/check --release`(기본 check와 분리, 2~4분):
   ```
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
   → aab(zip)에서 base/lib/arm64-v8a/libapp.so 꺼냄 → '__OPERATOR_PANEL__' 바이트 검색 → 있으면 실패
   flutter build apk --release --dart-define=OPERATOR=true --target-platform android-arm64
   → lib/arm64-v8a/libapp.so에 표식이 있어야 함(양성 대조) — 없으면 "검사가 작동하지 않음"으로 실패
   ```
   Dart 문자열 리터럴은 난독화돼도 그대로 남아서 검색된다.
3. 실행 시점: 내부 테스트 업로드 전(사람 절차 `docs/store/android-release.md`에 적는다).

## 옮길 코드 (S5가 실제 빌드로 확인함, 2026-10-14)

### A. 표식 상수 — `apps/game/lib/operator/operator_panel.dart`
패널 제목(또는 루트) 위젯의 Key로 **실제로 참조**해야 운영자 빌드에 남는다(참조 안 하면 양쪽 다 트리 셰이킹돼 양성 대조가 실패 = 검사가 알려 준다).
```dart
/// 배포 빌드 검사 표식 (tool/release_check.dart). 지우거나 바꾸지 말 것.
const operatorMarker = '__OPERATOR_PANEL__';
// 예: 패널 루트  Column(key: const Key(operatorMarker), children: [...])
```

### B. `tool/release_check.dart` (의존성 없음 — dart:io의 raw deflate로 zip을 직접 읽는다)
저장소 루트에서 `dart run tool/release_check.dart` (기본 표식 `__OPERATOR_PANEL__`). `--skip-build`는 이미 만든 산출물만 검사, `--marker`로 표식 교체.
check에 붙일 땐 `tool\check.bat --release` → 이 스크립트 호출(기본 check에는 넣지 않는다 — 2분 40초).

```dart
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
    await _flutter(app, ['build', 'apk', '--release', '--dart-define=OPERATOR=true', '--target-platform', 'android-arm64']);
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
  stdout.writeln('✓ 배포 빌드에 운영자 코드 없음');
}

Future<void> _flutter(Directory dir, List<String> args) async {
  stdout.writeln('> flutter ${args.join(' ')}');
  final p = await Process.start('flutter', args, workingDirectory: dir.path, runInShell: true, mode: ProcessStartMode.inheritStdio);
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
```

### 확인 결과
표식 대신 기존 운영자 전용 Key `op.invincible`로 돌림(표식 상수가 아직 없어서):
```
dart run release_check.dart --marker op.invincible
✓ Built app-release.aab (51.8MB) / ✓ Built app-release.apk (21.7MB, OPERATOR=true, arm64)
표식 "op.invincible": 배포 aab 0회 · 운영자 apk 1회
✓ 배포 빌드에 운영자 코드 없음        (2분 41초)
```
즉 지금 main(2497b11 기준) 배포 빌드에는 운영자 패널 코드가 남지 않는다. A가 들어오기 전에도 `--marker op.invincible`로 쓸 수 있다.

## 그동안
없음(수동: 문서의 절차대로 사람이 확인).

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
