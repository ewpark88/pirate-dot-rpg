# 레인: 경제·성장 (economy) — S2 항해사

- 브랜치: `lane/economy` · 폴더: `D:\Projects\pde-economy` · 진척: `docs/progress/economy.md`
- 소유 경로: `LANES.yaml` → `lanes.economy.paths`
- 설계서: 4.2 배 강화, 4.3 선원·카드·승급, 4.5 환생·일일, 4.6 광고, 4.7 오프라인, 4.8 밸런스, 5.3 BigNum, 7.2 밸런스 목표

## 목표
`EconomySystem`(`packages/game_core/lib/src/economy/economy_system.dart`)과 `game_cli sim`/`balance`를 만들어
밸런스 목표(설계서 7.2)를 숫자로 확인한다.

## 기다리지 않고 쓰는 입력
- 계약, 경제 테이블(crews·growth·rarities·ship_parts·ship_tiers·ads·meta — 이 레인 소유)
- 전투 DPS: `BattleSystem`이 없으면 추정식(설계서 4.7 초당 골드 추정)으로 시뮬한다

## 할 일 (M1 → M3)
1. 배 강화: 비용 `costBase × costGrowth^Lv`, 효과 공식, 25레벨 도약 ×2 → `PartUpgraded`/`PartMilestone`/`SaveRequested`
2. 배 승급(스테이지 기준 자동) → `ShipTierUp`
3. 소환: 확률·천장(50회 영웅 이상), 10연, 젬 비용 → `CrewSummoned`. 100만 회 시뮬 오차 0.2%p 테스트(설계서 9.3)
4. 카드 합치기(경험치), 승급(카드·골드·증표), 높은 등급 카드 즉시 점프, 신화 Lv75 초과 카드 → 증표
5. 보유 효과, 도감 보너스, 오프라인 보상(추정식, 8시간 상한, 시계 역행 0)
6. 광고 보상 `GrantAdReward`: 장치별 한도·하루 총 25회
7. 환생, 일일 퀘스트·출석(놓쳐도 초기화 없음), 자동 강화(스테이지 20 해금)
8. `game_cli sim` (가상 플레이어 정책: 가장 싼 강화, 젬 쌓이면 소환, 보스 실패 시 60초 파밍) — `--smoke`는 check에서 30초 이내
9. `game_cli balance crews` — 40명 × 5등급 × 대표 레벨 점수표, ±10% 벗어나면 실패

## 완료 기준
- 7.2 밸런스 목표 리포트, check의 밸런스 스모크가 ‘건너뜀’이 아니라 통과
- 운영자 명령: `OpSetCrew`, `OpGrant`, `OpSetShip`, `OpRebirthNow`, `OpAdvanceClock`, `OpReset`
- 2단계(M3~): 플랫폼 레인으로 역할 교대
