# 스펙: 전투 M3 — 해역 보스·중간 보스·무한 항해

- 상태: **승인됨** (2026-10-14, S1 — 사용자 위임) · 레인: battle (S1) · 설계서 절: 4.11, 4.4(보스 처치 연출은 렌더)

## 목적
- 단순한가: 보스 규칙은 한 줄로 설명된다("관통이 보호막을 깬다"). 플레이어가 편성을 바꿀 필요는 없다(자동 편성이 계열을 섞는다).
- 시원한가: 50스테이지마다 해역 보스가 나와 "이 계열이 잘 먹힌다"는 순간을 만든다.

## 규칙
1. **보스 종류**: 스테이지 `s`의 보스는 `s % 50 == 0`이면 해역 보스, `s % 25 == 0`이면 중간 보스, 그 밖에는 일반 보스(해역의 `boss`).
   `regions.json regions[]`에 `midBoss`, `regionBoss`(id)를 두고, `bosses[]`에 보스별 `hpMultiplier`(일반 보스 대비 배율), `weakFamilies`, `mechanic`을 둔다.
2. **패턴(`mechanic.type`)** — 수치는 테이블:
   - `frontArmor`(대왕 소라게): `bypassFamilies`(투척·공중) 외 계열의 피해 × `factor`(0.5).
   - `shield`(번개 가오리·빙산 바다코끼리): `intervalSec`마다 보호막. 보호막 중에는 다른 계열 피해 × `factor`(0.25), `breakerFamilies`(관통 / 충격)에게 맞으면 깨진다(그 공격 피해는 그대로).
     깨는 계열이 편성에 없어도 넘을 수 있어야 한다(sim에서 0이면 150에 영원히 막혔다 — 4.11 '편성을 바꿀 필요 없음').
   - `lava`(용암 고래): `intervalSec`마다 배에 보스 공격력 × `shipDamageMultiplier` 피해(무적이면 0).
   - `tentacles`(크라켄): 등장할 때 촉수 `count`개(보스 최대 체력 × `hpRatio`)가 함께 나오고, 촉수가 하나라도 살아 있으면 몸통은 피해 0(보호막과 같게 표시).
   - `summoner`(유령 함대 제독): `intervalSec`마다 그 해역 잡몹 `count`마리를 부른다.
   - 중간 보스는 패턴 없음(체력만 높다).
3. **무한 항해(300 이후)**: 해역은 `(stage − 1) % 300 + 1`로 다시 돈다. 체력·골드 곡선은 실제 스테이지 그대로 이어진다.
   바퀴 수 `lap = (stage − 1) ~/ 300`에 따라 적에게 등급 테두리 `tier = min(lap, 3)`(희귀·영웅·전설)를 붙인다.
4. **계약 추가**: `EnemyView.shielded`(bool, 기본 false), `EnemyView.tier`(int, 기본 0). 보스 약점 아이콘은 UI/렌더가 `regions.json bosses[].weakFamilies`를 읽는다.
5. 보스 제한 시간·실패·파밍 규칙은 M1 그대로.

## 수용 기준 — `packages/game_core/test/battle/battle_bosses_test.dart`
1. 스테이지 25 보스 = 산호초 중간 보스, 50 = 산호초 해역 보스(대왕 소라게), 51 = 폭풍해 일반 보스. 해역 보스 체력 = 일반 보스 × hpMultiplier.
2. 소라게: 직사 피해는 factor배, 투척 피해는 그대로.
3. 가오리: 보호막 중 직사 피해 factor배, 관통에 맞으면 보호막이 깨지고 피해가 들어간다. intervalSec 뒤 다시 생긴다. EnemyView.shielded가 따라간다.
4. 용암 고래: intervalSec마다 ShipDamaged, 무적이면 없음.
5. 크라켄: 등장 시 촉수 count개, 촉수가 살아 있으면 몸통 피해 0, 다 잘리면 들어간다.
6. 제독: intervalSec마다 잡몹 count마리가 생긴다.
7. 스테이지 301은 산호초, 적 tier = 1. 체력은 스테이지 301 곡선.
8. 같은 시드 → 같은 결과(보스전 리플레이).

## 운영자 모드
`OpJumpStage(50·100·…)` → `OpSpawnBoss`로 각 해역 보스를 바로 본다.
