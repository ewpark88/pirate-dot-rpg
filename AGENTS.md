# 해적도트 원정대 — 에이전트 가이드

도트 방치형 RPG. Flutter + Flame, 게임 규칙은 순수 Dart(`packages/game_core`). 이 파일은 지도다 — 자세한 것은 링크한 문서에.

## 시작할 때 (매 세션)
1. `docs/PROGRESS.md` — 지금 어디까지 됐고 다음에 뭘 할지. **항상 먼저 읽는다.**
2. 레인 세션이면 `/lane-start <레인>` → `docs/lanes/<레인>.md`, `docs/progress/<레인>.md`, 소유 경로(`LANES.yaml`)
3. `docs/ARCHITECTURE.md` — 레이어, 의존 규칙, 포트, 결정론
4. `packages/game_core/lib/contracts.dart` — 바꾸지 말 것. 필요하면 `docs/contracts/requests/`에 요청
5. 기획 질문은 `docs/GAME_DESIGN.md`(설계서). 설계서와 코드가 어긋나면 설계서가 기준

## 레드라인 (위반하면 tool/check 실패)
- 내 레인 경로(`LANES.yaml`) 밖의 파일을 수정하지 않는다 (main 브랜치 = S1 통합 세션만 예외)
- `game_core`는 Flutter, `dart:io`, `dart:ui`를 import하지 않는다
- `game_core`에서 `DateTime.now()`, `Random()`, `Stopwatch()` 직접 호출 금지 → `Clock`, `Rng` 포트
- 밸런스 수치는 `packages/game_data/tables/*.json`에만 (`battle/`·`economy/`의 0·1 외 숫자 리터럴 금지)
- 화면 문구는 내 레인의 ARB(`apps/game/lib/l10n/parts/<레인>.ko.arb`와 `.en.arb` 둘 다)에만. 키는 레인 접두어로 시작
- 세이브 스키마 변경 = 마이그레이션 함수 + `test/fixtures/saves/v<N>.json` 픽스처 필수
- 세이브 픽스처·골든 이미지는 고치지 않는다(훅이 막는다). 테스트가 틀리면 코드를 고친다
- 파일 하나 300줄 이하. 다른 패키지의 `lib/src/` import 금지
- 운영자 코드(`apps/game/lib/operator/`)는 `if (kOperator) { ... }` 안에서만 부른다
- 에셋은 `apps/game/assets/LICENSES.json`에 등록(CC0·OFL·MIT·OWN만)

## 완료 조건
- `tool\check.bat`(Windows) / `tool/check.sh`(Linux·macOS) 통과 — Stop 훅이 자동으로 돌린다. 커밋·머지 전에는 `--full`
  (GitHub Actions CI는 쓰지 않는다 — ADR-0006)
- 스펙의 수용 기준마다 테스트 1개 이상 (로직은 `scenarios/*.yaml` 또는 단위 테스트)
- 새 문구는 ko/en 둘 다, 영어 화면 골든 1장 포함
- 새 기능은 운영자 모드에서 바로 불러볼 수 있게 (`docs/GAME_DESIGN.md` 6.10)
- 밸런스 테이블을 바꿨다면 balance 리포트를 PR에 첨부
- **진척 문서 갱신**: main은 `docs/PROGRESS.md`, 레인은 `docs/progress/<레인>.md`. 안 하면 Stop 훅이 막는다

## 작업 흐름 (docs/GAME_DESIGN.md 6.7)
스펙(`docs/specs/<레인>-<주제>.md`, 사람 승인) → 계획(`docs/plans/active/<레인>-<주제>.md`) → 테스트 먼저(실패 확인)
→ 구현 → check 통과 → 진척 문서·계획 갱신 → 커밋(자기 브랜치) → 계획을 `plans/done/`으로

## 자주 쓰는 명령
| 명령 | 용도 |
| --- | --- |
| `tool\check.bat` / `--full` | 모든 검사 (목표 90초) / + Flutter 테스트 |
| `dart run tool/gen_tables.dart` | 테이블 JSON → `tables.g.dart` (테이블 수정 후, 훅이 자동 실행) |
| `dart run tool/merge_arb.dart` | ARB 조각 합치기 (check가 자동 실행) |
| `dart run game_cli replay --all` | 시나리오 리플레이 |
| `dart run game_cli sim` | 밸런스 시뮬 (M1 경제 레인) |
| `dart run game_cli export-events` | 렌더 레인용 전투 기록 갱신 (`--synthetic`: 합성본) |
| `dart run game_cli fixtures` | `fixtures/states`, `fixtures/events` 다시 만들기 |
| `dart run game_cli save inspect <파일>` | 세이브 검증·마이그레이션 결과 |
| `dart run game_cli balance crews` | 선원 균형 점수표(±10%)·조합 검사 (`--quick`은 check --full이 돌림) |
| `dart run tool/release_check.dart` | 배포 빌드(aab)에 운영자 코드가 없는지 + 운영자 빌드엔 있는지 (약 3~5분, 스토어 업로드 전) |

## 폴더
- `packages/game_data` 테이블+검증 · `packages/game_core` 규칙·계약·엔진 · `packages/game_cli` 헤드리스 도구
- `apps/game/lib/{render,ui,adapters,operator}` 앱 · `fixtures/` 레인용 가짜 입력 · `scenarios/` 수용 기준
- `tool/` 하네스(검사·코드젠·훅) · `docs/` 모든 결정의 유일한 기록
