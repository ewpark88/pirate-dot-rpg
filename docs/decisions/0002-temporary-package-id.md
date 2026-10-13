# ADR-0002: 임시 패키지 ID `repo.dot.pirate`, 저장소 폴더 `pirate-dot-rpg`

- 날짜: 2026-10-13 · 상태: 임시 (설계서 12장 미결 사항 “게임 이름과 패키지 ID 확정”)

## 결정
- Android `applicationId`/`namespace`, iOS `PRODUCT_BUNDLE_IDENTIFIER` = `repo.dot.pirate`
- Dart 패키지 이름 `pirate_dot`, 표시 이름 `Pirate Dot`(앱 안 제목은 l10n `uiAppTitle`)
- 저장소 폴더는 설계서의 `pirate-dot-expedition` 대신 `D:\Projects\pirate-dot-rpg`. worktree 이름(`pde-economy` 등)은 설계서대로.

## 남은 일
- 스토어 등록 전(M5) 최종 ID·영문명 확정 후 이 ADR을 “대체됨”으로 바꾸고 새 ADR 작성.
  Play에 한 번 올린 ID는 바꿀 수 없으므로 내부 테스트 업로드 전에 확정해야 한다.
