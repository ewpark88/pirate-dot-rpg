# ADR-0003: 데이터 테이블을 const 문자열로 임베드 (코드젠)

- 날짜: 2026-10-13 · 상태: 채택

## 맥락
`game_data`는 `dart:core`·`dart:convert`만 쓸 수 있다(설계서 3.1). 파일을 읽을 수 없고, Flutter 에셋 번들도 못 쓴다.
그런데 코어 테스트·CLI·앱이 같은 테이블을 같은 방식으로 읽어야 한다.

## 결정
`tool/gen_tables.dart`가 `packages/game_data/tables/*.json`을 `lib/src/tables.g.dart`의 `rawTables` const 맵으로 만든다.
- check가 생성물이 최신인지 비교하고, 다르면 실행할 명령을 알려준다.
- PostToolUse 훅이 테이블 JSON 수정 직후 자동으로 다시 만든다.
- 생성물은 커밋하고, 어느 레인이든 바꿀 수 있다(`LANES.yaml`의 `allLanes`). 머지 충돌 시 다시 생성.

## 결과
- 앱·CLI·테스트가 `GameTables.load()` 하나로 같은 데이터를 읽는다. 원격 조정(2차)은 `load(raw)`에 다른 맵을 넘기면 된다.
