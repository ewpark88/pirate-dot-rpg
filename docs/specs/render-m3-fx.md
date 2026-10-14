# 스펙: 렌더 M3 — 스킬·궁극기·적 역할 연출

- 상태: 승인됨 (2026-10-14, S1) · 레인: render(S3) · 설계서 절: 4.4 스킬과 궁극기·타격감, 4.11 해역과 적, 10장 아트 규격
- 엔진 쪽: `docs/specs/battle-m3-skills.md`(S1, 승인됨) · 계약 요청: `docs/contracts/requests/render-m3-events.md`
- 엔진 구현 전에는 테스트 안 고정 기록으로 개발한다(샘플 기록은 생성물이라 쓰지 않는다).

## 목적
- 시원한가: 스킬은 기본 공격보다 한 단계 크게, 궁극기는 계열마다 다른 모양으로 화면 전체를 쓸어낸다. 전설 화면 스킬은 화면 전체가 반응한다.
- 단순한가: 연출 모양은 `fx_map.json` 데이터(스킬 id·궁극기 id → 패턴·시트·배율). 선원·스킬이 늘어도 코드는 그대로.
- 피로가 없는가: 화면 전체 연출도 이펙트 40·숫자 24 상한 안. 흔들림·번쩍임 끄기 그대로 적용.
- 공정한가: 기록만 보고 그린다. 기절·장판처럼 기록에 없는 상태는 추측하지 않고 계약으로 받는다.

## 규칙
1. **스킬 시전**(`SkillCast(crewId, skillId, x, y)`): `skills.json`에서 skillId(계열 `skill` 또는 `crewSkills`)의 `fx`·`shape`를 찾아
   (x,y)에 시트를 `fx_map.skillFxScale`배(기본 1.5)로 재생 + 슬롯 강조. 같은 틱의 Damage는 지금처럼 개별 번쩍임·숫자.
   - `shape: ship`(예: `support_rally`): 배 위에 시트, 배 초록 번쩍임(회복), 버프 동안 배 테두리.
   - 원 여러 곳(`count` > 1): 엔진이 중심마다 `SkillCast`를 하나씩 낸다고 가정(계약 요청 A).
2. **전설 화면 스킬**: `SkillCast.scope == screen`(계약 요청 A)이면 화면 전체 연출 — 짧은 화면 플래시 + 화면 안 적마다 시트(상한 안에서 앞쪽부터)
   + 흔들림 `juice.shake.ultimate`의 절반. 계약 전 임시 어댑터: 같은 틱 그 선원의 Damage 대상 수 ≥ 화면 안 적 수의 80%면 화면 스킬로 본다.
3. **궁극기**(`UltimateCast(crewId, ultimateId)`): `fx_map.ultimates[ultimateId]`의 패턴으로 그린다. 패턴 4종:
   - `sweep`(해일·대파도·유령선 돌격): 큰 시트가 화면 왼쪽→오른쪽으로 `durationMs` 동안 지나간다.
   - `rain`(포탄 비·크라켄): 시트 `count`개가 화면 안 결정론적 위치(틱 기반)에 시차를 두고 터진다.
   - `strikes`(번개 폭풍·작살 폭풍): 화면 안 적 위치에 `count`개(적이 적으면 있는 만큼) 차례로.
   - `volley`(일제 사격): 배 앞머리에서 화면 끝까지 직사 발사체 줄 `count`개.
   흔들림 ultimate, 진동 medium은 지금 그대로. 넉백 계열은 엔진이 x를 옮기므로 보간이 그대로 보여 준다(추가 오프셋 없음).
4. **슬롯 덮개 둘**: 기본 공격 쿨타임 = 초상 위 어두운 덮개(지금), 스킬 쿨타임 = 초상 아래 3px 막대(차오름).
   `skillCooldown == 0`이면 막대 금색 + 테두리 깜빡임(준비됨).
5. **기절**: `EnemyView.stunned`(계약 요청 B)가 true면 머리 위 별 2개가 돈다. 계약 전에는 그리지 않는다(추측 금지).
6. **적 27종 플레이스홀더**: `regions.json enemies[]`의 `role`·`layer`로 색·크기를 정한다(`fx_map.enemyLook`):
   basic 빨강 12px · fast 노랑 10px · tough 회색 14px · air 흰색 10px · split 초록 12px(`_small` 8px) · revive 보라 반투명 12px. 표에 없는 종류는 basic.
7. **분열**: Kill 틱에 처치된 적 자리 6px 안에 새 id가 생기면 "분열 팝"(작은 hit_spark 2개 + 새 적이 2프레임 커졌다 작아짐).
8. **부활**: Kill 없이 같은 id의 `hpRatio`가 0.2 이상 다시 오르면 부활 연출(level_up 시트, 보라 번쩍임). 적은 사라지지 않는다.
9. **수중 장판**: `ZoneSpawned(x, y, radius, ticks, crewId)`(계약 요청 C)면 반투명 원을 남은 틱 동안 그리고 끝나면 사라진다(장판도 이펙트 상한에 포함).
   계약 전 임시 어댑터: underwater 계열 `AttackFired` 조준점에 `skills.json` 계열 `attack.radius`·사다리 첫 `dotSec`으로 그린다.
10. **수치**: 배율·시간·개수·색은 `fx_map.json`(`skillFxScale`, `ultimates`, `enemyLook`, `zone`)과 `juice.json`. 코드에는 배치 상수만.

## 수용 기준 (Given / When / Then) — `apps/game/test/render/`
1. Given `SkillCast(lob_rain)` When 재생 Then (x,y)에 `explosion_aoe`가 `skillFxScale`배로 생긴다. `support_rally`면 배 위 `level_up` + 배 회복 번쩍임.
2. Given 화면 스킬(`scope: screen` 또는 임시 어댑터 조건) When 재생 Then 화면 안 적마다 시트(상한 40 이하)와 화면 플래시.
3. Given 궁극기 8종 각각 When 재생 Then 모두 `fx_map.ultimates`에 패턴이 있고, sweep은 `durationMs` 중간에 화면 가운데를 지나며, 동시 이펙트 ≤ 40.
4. Given 슬롯 `cooldown 0.5, skillCooldown 0.25` When 그림 Then 덮개와 스킬 막대가 따로 보인다(골든), `skillCooldown 0`이면 준비 표시.
5. Given `stunned: true`인 적 When 그림 Then 별 표시(계약 B 반영 후. 그 전에는 테스트 skip + 사유).
6. Given `regions.json`의 모든 적 종류 When 모양 조회 Then 색·크기가 있고, `_small`은 작은 크기, 모르는 종류는 basic.
7. Given Kill 직후 같은 자리 새 id 2개 When 재생 Then 분열 팝 1번, 새 적 2마리가 그려진다.
8. Given Kill 없이 hpRatio 0→0.5 When 재생 Then 부활 연출 1번, 적은 계속 그려진다.
9. Given `ZoneSpawned(ticks: 40)`(또는 임시 어댑터) When 2초 재생 Then 장판이 보이다가 40틱 뒤 사라진다.
10. 골든 1장: 고정 기록 — 스킬 시전 + 궁극기 sweep 중간 + 분열 + 슬롯 덮개 둘 (`goldens/battle_m3.png`, 승인 필요).

## 문구 (ko / en)
없음. 스킬·궁극기 이름을 화면에 띄우는 건 UI(배너) 몫.

## 운영자 모드에서 불러보는 법
S1의 `OpCastSkill`·`OpSetWave(enemyKind)`로 엔진이 이벤트를 내면 라이브 재생으로 보인다. 렌더 단독 확인은 `BATTLE_SCENE=demo`에 M3 기록이 들어온 뒤.

## 결정 기록 (2026-10-14, S1)
- 계약 요청 A·B·C 모두 수용 — S1 전투 M3 커밋과 함께 main에 들어온다. 임시 어댑터(규칙 2·9)는 그때까지만, 기절 별(규칙 5)은 그 뒤에 켠다.
  - A: `SkillCast.scope`('normal'|'screen', 기본 normal). circle·line·single이 count>1이면 중심/대상마다 SkillCast(같은 틱).
  - B: `EnemyView.stunned`(bool, 기본 false). C: `ZoneSpawned(crewId, x, y, radius, ticks)`, JSON type `zoneSpawned`.
- `regions.json enemies[]`: `role`(basic|fast|tough|air|split|revive), 선택 `splitInto`·`splitCount`·`splitHpRatio`·`reviveHpRatio`.
  적 27종: crab, piranha, jelly, gull, urchin, flyingfish, stormgull, puffer, icecrab, icecrab_small, penguin, seal, snowgull, lavacrab,
  lavacrab_small, starfish, starfish_small, lavaturtle, firebird, angler, squid, siphon, eel, skeleton, ghostjelly, cursegull, wraith.
  보스 kind는 지금 모두 `enemy_ship`(해역 보스는 다음 스펙).
- 렌더는 `regions.json` 원문에서 `role`을 직접 읽는다(필드가 없으면 layer가 air면 air, 아니면 basic).
- 장판은 이펙트와 별도 풀(상한 `fx_map.zone.max`)로 그린다 — 오래 남는 원이라 이펙트 40개 회수 순서와 섞지 않는다.
