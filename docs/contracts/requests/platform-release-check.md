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

## 그동안
없음(수동: 문서의 절차대로 사람이 확인).

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
