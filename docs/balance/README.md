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

## 오늘 밤 실행 (2026-10-17, S1 시작 신호 뒤 — 사용자 '퇴근')
- 기준: **main 최신**(미커밋 수치로는 안 돌린다, S1 결정). 그때 main에 bossBreak 수치가 있으면 넣은 상태, 없으면 뺀 상태다.
- 어디서: S2 워크트리 `D:\Projects\pde-economy`에서 `git merge main`(작업 트리를 깨끗하게 — 미커밋은 패치로 빼 둠) → 아래.
- 순서(한 번에 하나, 잠금 파일이 있으면 시작 안 함):
  1. `python -I -B tool/nightly_sim.py` — 100명 × 30일 daily → `docs/balance/nightly-30d.md` (약 수십 분, 메모리 부족이면 자동으로 50명)
  2. (시간 남으면) 위협·보스 후보 확정 5명 × 3시간 continuous, 시드 1, 후보마다 하나씩:
     `%TEMP%\game_cli.exe sim --players 5 --hours 3 --set waves.monster.attackBase=9 --set waves.top.vanguard.attackMul=60 --set waves.top.vanguard.hpMul=10 --set waves.boss.attackMultiplier=35 --set waves.boss.hpMultiplier=40 --set waves.monster.goldBase=3.5 --set waves.boss.wallHpMultiplier=2.6 --out build/nightly/c5.json`
     (C3 · C5 · hull base 900/1200 변형 — 결과 표는 docs/progress/economy.md)
- 끝나면: 리포트 커밋(lane/economy) → S1에 '벗어남' 목록 + 전/후 표 보고, 잠금 파일이 지워졌는지 확인.
