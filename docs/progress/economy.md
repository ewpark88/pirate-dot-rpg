# economy 레인 진척 (S2)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 마일스톤 | M1 EconomySystem |
| 스펙·계획 | `docs/specs/economy-m1.md` (승인 2026-10-14) · `docs/plans/active/economy-m1.md` |
| 바로 다음 할 일 | 4단계: Summon + 천장 + receiveCard (기준 5~8, 11) |
| 막힌 것 | 없음 |

## 세션 로그 (최신이 위)

### 2026-10-14 · S2 · 스펙 승인 + 강화·선원 효과 함수 + 테이블 + UpgradePart
- 한 일:
  - 스펙(수용 기준 13개)을 쓰고 사용자 승인 → main 머지 후 `docs/specs/economy-m1.md`로 분리. 결정: ① 카드는 계약 유지(받을 때 경험치 적립, `cards`는 승급 장수)
    ② 보스 카드는 전투가 `grantBossCards`를 호출 ③ 테이블은 설계서 기준
  - `economy/ship_stats.dart`·`crew_stats.dart` 순수 함수 + 테스트 12개(테스트 먼저 실패 확인)
  - S1에 시그니처 안내: `docs/contracts/requests/economy-stats.md`. 보스 카드는 `grantBossCards(state, ctx, fleet)`, 스테이지 올리기 전 호출로 합의
  - 테이블을 설계서 기준으로: rarities 65/27/7/1 + `bossDropRates`, growth 등급별 `expToNext`·승급 카드 3/6/10/20·증표 50·`goldKills`·`bossCards`
    (모델 `crew_tables.dart` 갱신, 설계값 고정 테스트 `tables_design_test.dart`). sim 전이라 balance 리포트는 아직 없음
  - `UpgradePart` 구현 (수용 기준 1~4 + 부분 구매·모르는 부위) — economy 테스트 23개
  - 발견: check 레인 검사가 unstaged 첫 파일 경로의 첫 글자를 자르는 버그 → S1에 보고, main 136244a에서 수정
- 다음 할 일: 4단계 Summon·천장·receiveCard → 5단계 합치기·승급
- 협의: crews.json·waves.json은 S1이 고치는 중이라 건드리지 않는다(rarities/growth/ship_parts/meta만)
- 남은 문제: 최종 피해 % 보너스 합(`crewDamageBonus`)은 아직 없음
