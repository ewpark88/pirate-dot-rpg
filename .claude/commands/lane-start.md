---
description: 레인 브리핑을 불러와 오늘 할 일을 정한다 (/lane-start <battle|economy|render|ui|platform|art|main>)
argument-hint: <레인 이름>
---

레인 `$ARGUMENTS` 세션을 시작한다. 아래 순서대로 읽고, **레인 밖 코드는 읽지 않는다**(컨텍스트를 짧게 유지).

1. `AGENTS.md` — 레드라인과 완료 조건.
2. `docs/PROGRESS.md` — 전체 진척, 현재 마일스톤, 다른 레인 상태(막힌 것 포함).
3. 레인이 `main`이면 S1(선장·통합) 역할이다: `docs/contracts/requests/`의 미처리 요청서와 `docs/lanes/battle.md`를 읽는다.
   그 외에는 `docs/lanes/$ARGUMENTS.md`와 `docs/progress/$ARGUMENTS.md`(없으면 만든다)를 읽는다.
4. `LANES.yaml`에서 `$ARGUMENTS` 레인의 `paths` — 이것만 수정할 수 있다.
5. `docs/plans/active/$ARGUMENTS-*.md` — 진행 중인 계획. 없으면 오늘 목표로 새 계획을 만든다.
6. `git status`와 현재 브랜치를 확인한다. 레인 브랜치(`lane/$ARGUMENTS`)인데 main보다 뒤처졌으면 `git merge main`을 먼저 제안한다.

그다음 사용자에게 다음 형식으로 짧게 보고한다:

- 현재 위치: (진척 문서 기준 한 줄)
- 오늘 할 일: (계획의 다음 단계 1~3개)
- 막힌 것 / 계약 변경 요청 필요 여부:

작업 중 규칙:
- 계약(`packages/game_core/lib/contracts.dart`과 공유 경로)을 바꿔야 하면 직접 고치지 말고 `docs/contracts/requests/$ARGUMENTS-<주제>.md`를 쓰고 임시 어댑터로 계속한다.
- 끝낼 때: `tool\check.bat`(또는 `tool/check.sh`) 통과 → 진척 문서(main은 `docs/PROGRESS.md`, 레인은 `docs/progress/$ARGUMENTS.md`)에 한 일·다음 할 일·남은 문제 기록 → 계획 파일 갱신. Stop 훅이 이 둘을 검사한다.
