# 스펙: 렌더 — 해역 배경 6종 · 보스 등장/처치/실패 연출

- 상태: 승인됨 (2026-10-14, S1) · 레인: render(S3) · 설계서 절: 4.4 타격감(보스 처치), 4.11 해역과 적, 10장 해역 배경(320×148, 하늘·원경·바다 3층)
- 계약 요청: `docs/contracts/requests/render-stage.md` (BattleView에 스테이지)

## 목적
- 시원한가: 보스가 나오면 화면이 긴장하고(붉은 경고), 잡으면 0.3초 슬로모션 + 플래시 + 코인 비로 크게 보상한다.
- 단순한가: 배경은 해역마다 색 3층 + 장식 하나. 해역이 바뀌면 1초 동안 섞이며 넘어간다.
- 피로가 없는가: 경고·플래시는 짧게, 번쩍임 끄기 설정을 따른다. 보스 실패는 벌주지 않고 잠깐 어두워질 뿐(파밍으로 이어짐).
- 공정한가: 해역은 기록의 스테이지로만 정한다(추측 없음).

## 규칙
1. **해역 결정**: `BattleView.stage`(계약 D) → `regions.json regions[]`의 `fromStage`로 해역 → `background` id.
2. **배경 플레이스홀더**(`fx_map.backgrounds[bgId]`): 하늘·바다·깊은 바다 색 + 원경 장식 1종
   (`islands` 산호초 섬 / `clouds` 폭풍 먹구름 / `icebergs` 빙산 / `smoke` 화산 연기 / `none` 심해 / `fog` 유령 안개, 단색 사각 몇 개).
   모르는 id는 `bg_coral`. 아트가 오면 같은 id의 3층 이미지로 바꾼다(아트 레인).
3. **해역 전환**: 스테이지가 다른 해역으로 바뀌면 `fx_map.backgroundFadeMs`(1000) 동안 두 배경 색을 섞는다.
4. **보스 등장**(`BossSpawned`): 화면 가장자리 붉은 테두리가 `bossEntrance.ms` 동안 두 번 깜빡이고(번쩍임 설정 따름), 흔들림 aoe 1회.
   보스 HP 바는 보스 머리 위 큰 바(지금처럼), 남은 시간 바는 UI HUD 몫.
5. **보스 처치**(보스 `Kill` 또는 `BossCleared`, 한 번만): 지금 있는 슬로모션(`juice.bossKill.slowMoMs`·`slowMoRate`)·화면 플래시·흔들림 bossKill에
   **코인 비** 추가 — 화면 위에서 `juice.bossKill.coinRain`개(코인 풀 상한 안)가 결정론적 x로 떨어져 배로 빨려간다.
6. **보스 실패**(`BossFailed`): `bossFailed.ms` 동안 화면이 살짝 어두워진다(검정 30%). 흔들림·진동 없음.
7. **보스 모양**(`fx_map.bossLook[kind]`: 색·가로·세로): 일반 `enemy_ship` 40, 25스테이지 중간 보스 6종(raider_ship, storm_pirate, icebreaker,
   fire_pirate, deep_sub, ghost_ship) 44, 50스테이지 해역 보스 6종(giant_hermit, thunder_ray, iceberg_walrus, lava_whale, kraken, ghost_admiral) 52,
   `kraken_tentacle`(크라켄 촉수 4개, 각자 적) 12×28 세로 막대. 표에 없는 보스는 `enemy_ship` 모양.
8. **보호막**(`EnemyView.shielded`): 적 둘레 2px 청록 테두리. 보호막이 true→false로 바뀌는 틱에 "깨짐"(청록 hit_spark 3개).
9. **무한 항해 테두리**(`EnemyView.tier` 0~3): 0은 없음, 1~3은 `fx_map.tierColors`(동·은·금) 1px 테두리. 보호막과 같이 있으면 보호막이 바깥.
10. **약점 계열**(`regions.json bosses[].weakFamilies`) 아이콘은 UI HUD 몫 — 렌더는 그리지 않는다.
11. **보물상자**(`BattleView.chest`: x·y·ticksLeft, 경제가 띄움): null이 아니면 바다 위에 상자를 그리고 위아래로 둥둥(`fx_map.chest.bobPx`·`bobMs`),
    남은 틱이 `sinkTicks`보다 적으면 그만큼 가라앉으며(`sinkPx`) 흐려진다. 탭 판정은 UI가 같은 좌표로 한다(렌더는 그림만).
12. **수치**: `fx_map.json`(`backgrounds`, `backgroundFadeMs`, `bossEntrance`, `bossFailed`, `bossLook`, `shield`, `tierColors`, `chest`), `juice.json`(`bossKill.coinRain`).

## 수용 기준 (Given / When / Then) — `apps/game/test/render/`
1. Given `regions.json`의 배경 id 6개 When 조회 Then 모두 `fx_map.backgrounds`에 있고, 모르는 id는 `bg_coral`.
2. Given stage 1·50·51·150·251·400 When 해역 결정 Then coral·coral·storm·glacier·phantom·storm(무한 항해 300 반복 — `regions.regionAt`, 2026-10-14 수정).
3. Given stage 50 → 51 When 재생 Then `backgroundFadeMs`의 절반에서 하늘색이 두 해역 색의 중간, 끝나면 storm 색.
4. Given `BossSpawned` When 재생 Then 경고 테두리가 켜지고 `bossEntrance.ms` 뒤 꺼진다. 번쩍임 끄기면 켜지지 않는다.
5. Given 보스 `Kill` 다음 틱 `BossCleared` When 재생 Then 처치 연출은 한 번, 코인 비 `coinRain`개(코인 상한 이하), 슬로모션 동안 재생 속도 = `slowMoRate`.
6. Given `BossFailed` When 재생 Then `bossFailed.ms` 동안 어두움, 흔들림 진폭 0.
7. Given 보스 kind 13종(+촉수) When 모양 조회 Then 모두 `bossLook`에 있고, 모르는 보스 kind는 `enemy_ship` 모양.
8. Given `shielded` true→false When 재생 Then 깨짐 연출 1번, 그 뒤 보호막 테두리 없음.
9. Given `tier` 0·1·2·3 When 그림 Then 0은 테두리 없음, 1~3은 `tierColors` 색.
11. Given 프레임 stage 50 → 51 When 재생 Then 장면 배경이 storm으로 섞여 넘어간다(`frame.stage` 사용).
12. Given `chest`(ticksLeft 충분) When 그림 Then 상자가 (x, y±bobPx) 안에 보인다. ticksLeft < sinkTicks면 가라앉음 > 0, chest null이면 안 보인다.
10. 골든 1장: 폭풍해 배경 + 중간 보스(보호막·tier 2) 등장 경고 + 무리 (`goldens/battle_boss_storm.png`, 승인 필요).

## 문구 (ko / en)
없음 — 해역 이름·보스 경고 문구 배너는 UI(battle ARB `battleRegion*` 키 이미 있음).

## 운영자 모드에서 불러보는 법
S1/S4 운영자 명령(스테이지 이동·보스 소환)으로 엔진이 이벤트를 내면 라이브로 보인다. 렌더 단독: 고정 기록 테스트·골든.

## 결정 기록 (2026-10-14, S1)
- 계약 D 수용: `BattleView.stage`(int, JSON 없으면 1) main 16dda02(ADR-0008)에 반영. 같이 `BattleView.chest`(ChestView) 추가 — 규칙 11.
- 해역 보스(battle-m3-bosses): 보스 kind가 스테이지별로 바뀌고 `EnemyView.shielded`·`tier`(0~3)가 추가된다 — 규칙 7~10으로 포함.
