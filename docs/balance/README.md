# 밸런스 리포트 (economy 레인 S2)

설계서 6.4 ‘매일 밤 가상 플레이어 100명 × 30일 밸런스 리포트’와 M3 완료 조건 ‘야간 시뮬 30일 리포트가 목표 범위 안’.
CI는 ADR-0006대로 없으므로 로컬에서 돌려 커밋한다.

## 파일
| 파일 | 내용 |
| --- | --- |
| `nightly-30d.md` | 가상 플레이어 100명 × 30일, 하루 40분 일정(20분 → 8시간 → 20분 → 15시간 20분). 생성물이라 손으로 고치지 않는다 |

## 돌리는 법 (저장소 루트에서)
```bat
cd packages\game_cli
dart compile exe bin\game_cli.dart -o %TEMP%\game_cli.exe
cd ..\..
%TEMP%\game_cli.exe sim --players 100 --days 30 --schedule daily --report docs/balance/nightly-30d.md
```
- 한 번에: `python -I -B tool/nightly_sim.py` (컴파일 → sim → 리포트, 잠금·메모리 확인·build/nightly/log.csv 기록, `--dry-run`·`--players 50`). 손으로 할 때는 위 순서.
- `dart run`보다 컴파일한 exe가 빠르다. 100명 × 30일은 단일 스레드로 수십 분 걸린다.
- 메모리: 다른 무거운 일(Flutter 테스트·빌드)과 겹치지 않게 **한 번에 하나만** 돌린다. 메모리 부족이면 `--players 50`으로 줄이고 리포트에 그 사실을 적는다.
- 목표 범위는 `packages/game_data/tables/meta.json` `sim.targets`. 벗어나면 종료 코드 1(스모크 `--smoke`만 경고).
- 30일 리포트는 28일 넘는 목표(첫 신화 28~56일)를 시간 안에 못 보면 ‘판정 안 함’으로 둔다.

## 탐색용 옵션
- `--set table.key=값` — 테이블 값을 덮어써서 다시 빌드 없이 변형 비교(예: `--set growth.expToNext.legend=26`).
- `--boss-ad` — 보스 실패 때 함포 지원 광고를 보고 바로 재도전(하루 한도까지).
- `--out report.json` — 플레이어별 값·회차별 카드 수입 JSON.

## 오늘 밤 실행 (2026-10-17, S1 시작 신호 뒤 — 사용자 '퇴근') — 최종 목록
- 기준: **main 최신**(미커밋 수치로는 안 돌린다). 어디서: `D:\Projects\pde-economy`에서 `git merge main` → 작업 트리 깨끗한지 확인 → 아래 순서, 한 번에 하나(잠금 파일 있으면 기다림).
1. **보스 무제한 확정**(5명 × 3시간 continuous, 후보마다 하나씩): 출발값 보스 HP ×160·공격 ×35·벽 ×2.0·goldBase 3.0 ± (HP 140/180 · 공격 30/45 · gold 2.9/3.1).
   목표: 처치 20~40초 · 침몰까지 15~30초 · 보통 첫 도전 70~85% · 벽 ~50% · 보스전 피해 25~45% · 스테이지 40 45~55분. 같이 봄: 강화 간격 35~45(→ 120초 이하, 안 되면 goldGrowth 1.135), 금고 가득 시간(초반 8~10분).
2. **balance crews 재적합**(같은 slot): 2차 특성 5명(sword·saw·bara·lobster·davy) · 강습 5(shark·crabby·king·lobster·davy — 배 지킴이) · 공중 4(polly·gull·alba·manta — 일반 탄). 5레벨 ±10%, `docs/balance/` fit 절차(aim → 전설 → 신화 powerScale).
3. **보스 특성 hpFactor 확인**: 재생 0.8·호위 0.85(추정)를 1의 확정값으로 5명 × 3시간 — 특성 보스(중간 25단위·대보스 10단위)의 bossKillSec가 특성 없는 보스와 ±10%면 OK.
4. **100명 × 30일**: `python -I -B tool/nightly_sim.py` → `docs/balance/nightly-30d.md` — 첫 전설(1~4일)·첫 신화(28~56일)·수집 보상 영향·피버 간격(200킬 고정).
- 끝나면: 수치 커밋(lane/economy) + BALANCE.md 변경 기록 + S1에 '벗어남' 목록·전/후 표, 잠금 파일 지워졌는지 확인.

