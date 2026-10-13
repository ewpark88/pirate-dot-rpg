# ADR-0004: game_core에 `crypto` 허용 (세이브 체크섬)

- 날짜: 2026-10-13 · 상태: 채택

## 맥락
설계서 3.1은 `game_core`의 의존을 `game_data`, `meta`, `collection`으로 제한한다. 그런데 세이브 체크섬(sha256, 5.2)은
코어의 `SaveCodec`에 있어야 앱·CLI·테스트가 같은 코드로 검증한다.

## 결정
순수 Dart이고 Flutter·플랫폼에 의존하지 않는 `crypto`를 허용 목록에 더한다(`tool/lib/src/deps.dart`).
`dart:math`·`dart:async`·`dart:collection`·`dart:typed_data`도 순수 Dart 표준 라이브러리라 허용한다.

## 결과
- 체크섬은 보안이 아니라 파일 손상 탐지용이다. 조작 방지가 필요해지면(랭킹 2차) 서버 측 도달 가능성 검사로 한다.
