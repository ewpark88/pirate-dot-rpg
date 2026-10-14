# 스펙: 전투 기록 재생 + 타격감

- 상태: 승인됨 (2026-10-14, S1 — 사용자가 S1에 위임했다는 S1 전달) · 레인: render(S3) · 설계서 절: 4.4 타격감 규칙, 10장 아트 규격
- 계획: `docs/plans/active/render-battle-replay.md`

## 목적
전투 기록(`RecordedTick` JSONL)만 보고 Flame 전장이 “계속 터지는” 장면을 그린다. 엔진을 기다리지 않는다.
- 시원한가: 무리가 한 번에 터지고, 히트스톱·흔들림·번쩍임·숫자가 매 타격에 붙는다.
- 단순한가: 화면에 움직이는 것은 배·적·발사체·이펙트뿐. 렌더는 명령을 내지 않는다.
- 피로가 없는가: 이펙트 40·숫자 24 상한, 흔들림·번쩍임·진동은 설정에서 끈다.
- 공정한가: 렌더는 기록을 바꾸지 않는다(결정론은 코어 몫). 같은 기록 → 같은 화면.

## 규칙
1. **고정 해상도**: 논리 320×180(전장 y 0~148, 슬롯 148~180), 정수배 + nearest. 기존 `CameraComponent.withFixedResolution` 유지.
2. **재생기**(`RecordingPlayer`, Flame 없는 순수 Dart): 틱 50ms × `speed`. 표시 시각은 최신 틱보다
   **lookahead 2틱(100ms) 늦게** 둔다 → 같은 틱에 나오는 `AttackFired`/`Damage`의 발사체 비행을 피격 직전 100ms 동안 보여 줄 수 있다.
   두 틱 사이는 적 id로 짝지어 x·y 선형 보간. 새 적은 그 자리에 등장, 사라진 적은 `Kill`이 있으면 처치 연출, 없으면 그냥 제거.
   `frame.hitStopTicks > 0`인 구간은 보간·이펙트 시계를 멈춘다(아래 결정 기록).
   끝까지 가면 처음부터 반복(데모·골든용, 끌 수 있음).
3. **층**: `layer` 값마다 그리기 순서와 색조 — underwater(배 아래, 어둡게) → surface → air(위). 좌표는 기록 값 그대로 쓴다.
4. **배**: 왼쪽 고정(앞머리 x=56). 플레이스홀더 사각 약 56×46. `ShipDamaged` → 배 번쩍임 + HP 바.
5. **발사체**: `AttackFired.family` 8종(lob·direct·pierce·skip·underwater·air·assault·shock) → `fx_map.json`의 `projectiles`에서 색·크기·비행 모양(포물선/직선/물수제비/낙하).
   배 앞머리에서 조준점(x,y)으로 lookahead 동안 날아간다. `targetIds`마다 1발(직사는 연사 수만큼 시차). `support`는 `shock`의 옛 이름으로 받아 준다.
6. **이펙트**: `fx_map.json` events → 시트 id. 아트 전에는 시트 크기·프레임 수 그대로 단색 사각(프레임마다 줄어드는 알파)으로 그린다.
7. **타격감**(수치는 `juice.json`):
   - 피격 적 흰색 번쩍임 `flashFrames`
   - 넉백: lob/explosion 계열 피격 시 폭발 중심 바깥으로 `knockbackPx.explosion`, assault는 `knockbackPx.assault` (보간 위치에 오프셋, 시간 지나면 0)
   - 흔들림: `AoeDamageSum` → aoe, `UltimateCast` → ultimate, 보스 `Kill`/`BossCleared` → bossKill (px·ms, 감쇠)
   - 데미지 숫자: 일반 흰색 2배, 치명 노랑 3배 + 튀기, `AoeDamageSum` 큰 숫자 1개(주황). `BigNum` 포맷은 코어 `big_num_format` 사용
   - 처치: 파편 + 코인 분수 → 배로 빨려감. 보스 처치: 0.3초 슬로모션 + 플래시
   - 진동: 이벤트로 신호만 낸다(`onHaptic` 콜백, 실제 진동은 UI/어댑터가 연결)
8. **설정**(`JuiceSettings`): shake·flash·vibration 각각 on/off, 절전(30fps). 앱 설정 연결은 UI 레인, 렌더는 값만 받는다.
9. **상한·풀링**: 동시 이펙트 40(넘치면 가장 오래된 것 회수), 데미지 숫자 24(넘치면 가장 오래된 둘을 합침). 모든 일시 객체는 미리 만든 풀에서 꺼낸다 → 워밍업 뒤 프레임당 새 컴포넌트 생성 0.
10. **운영자 값 노출**: `BattleGame.stats`(fps·이펙트 수·숫자 수), 히트박스 표시 플래그. 패널은 UI 레인.
11. **앱 데모 기록**: `apps/game/lib/render/demo/sample_battle.g.dart`의 const String(jsonl 원문)을 `decodeRecording()`으로 읽는다.

## 수용 기준 (Given / When / Then) — 테스트 1개 이상씩, `apps/game/test/render/`
1. Given 기록 2틱(적 x 300→298) When 표시 시각이 두 틱의 중간 Then 적 x = 299.
2. Given lookahead 2틱 When 틱 t의 `AttackFired` Then 발사체는 표시 시각 t-2틱에 생성되고 t에 조준점에 닿는다.
3. Given `frame.hitStopTicks > 0`인 연속 프레임 When 시간이 흐름 Then 보간 위치·이펙트 진행이 멈춘다.
4. Given 한 틱에 이펙트 60개 요청 When 처리 Then 동시 이펙트 ≤ 40.
5. Given 숫자 30개 요청 When 처리 Then 화면 숫자 ≤ 24이고 합계 피해는 보존된다.
6. Given 샘플 기록 1회 재생(워밍업 후) When 반복 재생 Then 풀이 새 객체를 만들지 않는다(생성 카운터 불변).
7. Given shake·flash off When `AoeDamageSum`/`Damage` Then 카메라 오프셋 0, 번쩍임 없음.
8. Given `UltimateCast` When 처리 Then 흔들림 진폭 = juice ultimate px.
9. Given family 8종 + `support` When 발사 Then 모두 발사체 스타일이 있다(`support`는 경고 없이 shock으로, 미지 계열은 기본 스타일).
10. 골든: 샘플 기록 tick 24(범위 처치 직후) 화면 1장 `apps/game/test/render/goldens/` (새 골든 → 사람 승인).
11. Given `sample_battle.g.dart` When `decodeRecording` Then `fixtures/events/sample_battle.jsonl`과 같은 틱 수·내용.

## 문구 (ko / en)
없음(데미지 숫자는 숫자 포맷만). 문구가 생기면 render 레인 ARB 조각이 LANES.yaml에 없으므로 그때 요청서.

## 운영자 모드에서 불러보는 법
UI 레인이 `BattleGame.stats`·히트박스 플래그·`JuiceSettings`를 패널에 연결(이번 범위 밖, 값만 노출).

## 결정 기록 (S1 답변, 2026-10-14)
- 히트스톱: 엔진은 멈춘 동안 시뮬을 돌리지 않고 `tick`도 그대로, `hitStopTicks`만 매 틱 1씩 줄여 같은 위치 프레임을 연속으로 낸다.
  `HitStop` 이벤트는 원인 틱에 나오고 다음 틱부터 멈춘다. → 규칙 2대로 `hitStopTicks>0` 구간에서 보간·이펙트 시계 정지.
- 앱 데모 기록: 에셋 대신 Dart 상수 `apps/game/lib/render/demo/sample_battle.g.dart`(const String, jsonl 원문, `*.g.dart`라 분석·300줄 검사 제외).
  지금은 렌더가 만들고, 전투 M1 끝에 `game_cli export-events`가 같이 쓰도록 S1이 바꾼다(allLanes 등록).
- 실제 엔진 특성(main f664a25 공지): 적은 x 300부터 12px 간격으로 줄지어 들어오고 화면 밖(x>320)에서도 생성된다 → 렌더는
  x>320 적도 객체는 유지하되 화면 밖이라 안 보일 뿐. 공격은 x≤320 적만 노린다. `AttackFired.x/y` = 조준점(원형은 폭발 중심, push는 배 앞).
  보스는 x 300, surface y 100.
- `sample_battle.g.dart`는 S1이 export-events로 실제 엔진 기록과 함께 쓴다. 그 전에는 렌더가 테스트에서 fixture를 직접 읽고,
  데모용 임시 상수가 필요하면 같은 경로에 fixture 사본을 둔다(S1 버전이 오면 덮어씀).
- 좌표: 실제 엔진 출력은 층 기준 y(air 44 / surface 100 / underwater 124 ±7). 렌더는 기록 좌표를 그대로 쓴다.
