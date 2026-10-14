# economy 레인 진척 (S2)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 마일스톤 | M1 EconomySystem |
| 스펙·계획 | `docs/specs/economy-m1.md` (승인 2026-10-14) · `docs/plans/active/economy-m1.md` |
| 바로 다음 할 일 | 2단계: rarities·growth 테이블을 설계서 기준으로 + 모델 |
| 막힌 것 | 없음 |

## 세션 로그 (최신이 위)

### 2026-10-14 · S2 · 스펙 승인 + 강화·선원 효과 함수
- 한 일:
  - 스펙(수용 기준 13개)을 쓰고 사용자 승인 → main 머지 후 `docs/specs/economy-m1.md`로 분리. 결정: ① 카드는 계약 유지(받을 때 경험치 적립, `cards`는 승급 장수)
    ② 보스 카드는 전투가 `grantBossCards`를 호출 ③ 테이블은 설계서 기준
  - `economy/ship_stats.dart`·`crew_stats.dart` 순수 함수 + 테스트 12개(테스트 먼저 실패 확인)
  - S1에 시그니처 안내: `docs/contracts/requests/economy-stats.md`
- 다음 할 일: 2단계 테이블 정리 → 3단계 UpgradePart
- 남은 문제: 최종 피해 % 보너스 합(`crewDamageBonus`)은 아직 없음
