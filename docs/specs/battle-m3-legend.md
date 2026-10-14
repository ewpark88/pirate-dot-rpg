# 스펙: 전투 M3 — 선원별 전설 고유 능력·신화 강화

- 상태: **승인됨** (2026-10-14, S1 — 사용자 위임) · 레인: battle (S1) · 설계서 절: 4.10 선원 40명, 4.8 예산

## 목적
- 시원한가: 전설에 오르면 같은 계열이라도 선원마다 눈에 띄게 다른 일이 일어난다(먹물 장판, 체인 기절, 해골 소환…).
- 단순한가: 선원 40명의 능력은 코드가 아니라 `skills.json`의 `legends`(선원 id별) 데이터다(crews.json은 경제 레인 소유라 전투 데이터는 skills에). 코드는 아래 효과 부품 8개뿐이다.
- 공정한가: 능력은 '모양'을 바꾸고 예산(4.8)은 지킨다 — 발사체가 늘면 한 발 피해가 준다. 숫자는 balance 점수표로 ±10% 안을 맞춘다(별도 작업).

## 규칙
1. 선원 등급이 **전설 이상**이면 `skills.json legends[선원 id]`가 기본 공격에 더해진다. **신화**면 `legend.mythic`의 값으로 같은 키를 덮어쓴다(설계서 4.10의 '신화 강화').
2. 효과 부품(모두 선택):
   - `extraProjectiles` n: 서로 다른 대상에 n발 더(한 발 피해 = 기본 ÷ 전체 발수).
   - `extraChains` n: 연쇄·관통 대상 +n. `noFalloff`: 연쇄·관통 감쇠 없음.
   - `onHit`: 맞은 적에게 — `slow`(이동 감소 비율)·`slowSec`, `burnSec`·`burnRatio`(그 공격 피해 × 비율을 지속 시간 동안 나눠), `stunSec`,
     `vulnerable`(받는 피해 +비율)·`vulnerableSec`(같은 종류는 큰 것 하나만 — 4.8), `pull`(조준점 쪽으로 px).
   - `zone`: 맞힌 자리에 장판 — `radius`·`sec`·`slow`·`stunEverySec`(장판 안 적 주기 기절). 장판 피해는 없음(지속 피해 장판은 수중 계열 규칙).
3. 보스는 기절·끌어당김·감속을 `bossControlFactor`(절반)만 받는다(4.10).
4. 감속은 이동 속도에, 받는 피해 증가는 모든 피해에 곱한다. 화상은 장판처럼 매 틱 피해(Damage 이벤트)로 나온다.
5. 렌더용 이벤트는 새로 만들지 않는다 — 장판은 ZoneSpawned, 기절은 EnemyView.stunned. 감속·화상·취약 표시는 렌더가 원하면 계약 요청.

## 선원별 값 (설계서 4.10 표 → 부품)
`skills.json legends`에 40명 모두 채운다. 대표 예: 옥토 = zone(slow 0.3, 3초) / 신화 zone 반경 2배, 팡 = 치명타 시 작은 폭발 → onHit 대신 `critBurst`(반경) 부품,
볼트 = extraChains 2 + onHit stun 0.3 / 신화 extraChains 4, 나르 = noFalloff, 램프 = onHit vulnerable 0.15·4초 / 신화 0.25.
설계서 문구 중 부품으로 그대로 안 되는 것(해골 선원 소환, 산호벽, 왕복 작살)은 가까운 부품으로 바꾼다:
소환 → extraProjectiles, 산호벽 → zone(stunEverySec), 왕복 → extraProjectiles(같은 줄 한 번 더).
→ 부품 하나 추가: `critBurst` radius (치명타일 때 맞은 자리 원형 범위 피해 × `critBurstDamage`(0.5)).

## 수용 기준 — `packages/game_core/test/battle/battle_legend_test.dart`
1. 전설 미만이면 legend가 적용되지 않는다. 전설이면 적용, 신화면 mythic 값으로 덮인다.
2. extraProjectiles: 발수가 늘고 한 발 피해가 그만큼 준다(합계 같음).
3. extraChains·noFalloff: 연쇄 대상 수가 늘고, noFalloff면 비율이 모두 1.
4. onHit slow: 감속 중 이동 거리가 (1 − slow)배. 보스는 절반만.
5. onHit burn: burnSec 동안 Damage가 나오고 합이 공격 피해 × burnRatio(±1%).
6. onHit vulnerable: 다른 선원의 피해가 (1 + vulnerable)배, 같은 종류는 큰 값 하나.
7. zone: ZoneSpawned, 안의 적 감속(·주기 기절), sec 뒤 사라짐.
8. critBurst: 치명타일 때만 주변 적이 맞는다.
9. 40명 모두 legend 데이터가 있고 테이블 검증을 통과한다(키 오타 → 검증 실패).
10. 같은 시드 → 같은 결과.
