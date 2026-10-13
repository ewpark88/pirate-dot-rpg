# ADR-0006: GitHub Actions CI를 쓰지 않는다

- 날짜: 2026-10-13 · 상태: 채택 · 설계서 6.4(CI·야간 밸런스)와 다름

## 맥락
M0에서 `ci.yml`(push마다 `check.sh --full` + debug APK)과 `nightly.yml`(야간 밸런스)을 넣었다.
첫 실행은 두 번 실패했다(커밋되지 않은 merged ARB, `check.sh` 실행 권한). 둘 다 고쳤지만, CI 결과를 확인하려면 웹에 들어가거나
`gh` CLI로 로그인해야 한다. 사람이 혼자 운영하는 프로젝트에서 이 확인 절차는 짐이 된다.

## 결정
GitHub Actions 워크플로를 두지 않는다. 같은 검사는 로컬에서 강제한다.
- 매 작업 끝: Stop 훅이 `tool/check.dart`를 실행한다(실패하면 종료가 막힘).
- 커밋·머지 전: `tool\check.bat --full`. S1은 레인을 머지할 때마다 실행한다.
- 야간 밸런스(가상 플레이어 100명 × 30일): 경제 레인이 `game_cli sim`을 구현한 뒤(M1) 필요할 때 로컬에서 실행한다.
- iOS 빌드는 Codemagic 자체 설정으로 하고, M6에 다시 결정한다.

## 결과
- 원격에서 자동으로 검사하지 않으므로, 로컬 check를 건너뛰고 push하면 아무것도 막지 않는다. 이 위험은 Stop 훅으로 줄인다.
- 다시 필요해지면 커밋 `4be7317`의 `.github/workflows/`를 복원한다. `merged` ARB 커밋과 `check.sh` 실행 권한 수정은 이미 반영되어 있어서 바로 동작해야 한다.
