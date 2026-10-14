# 스펙: 렌더 성능 측정 준비 (실기기 60fps 관문)

- 상태: 초안 — 승인 대기 · 레인: render(S3) · 설계서 절: 4.4 가독성 상한·풀링, 4.9 피로·절전, 6.10 운영자 모드, 11장 M2 관문
- 앞 스펙: `docs/specs/render-battle-replay.md` (완료)

## 목적
M2 관문 "저사양 실기기 60fps"를 사람이 한 번에 판단할 수 있게, 최악 장면을 재현하고 숫자로 보여 준다.
- 시원한가: 상한(이펙트 40·숫자 24)까지 꽉 찬 장면에서도 끊기지 않는지 본다.
- 단순한가: 운영자 패널에서 버튼 하나(부하 장면)와 숫자 몇 개(fps·프레임 시간·개수)만.
- 피로가 없는가: 절전 모드가 실제로 30fps로 그린다(배터리·발열).
- 공정한가: 측정 장면은 결정론적 — 기기마다 같은 장면을 비교한다.

## 규칙
1. **프레임 측정**(`PerfMonitor`, 순수 Dart): 최근 120프레임의 프레임 시간으로 p50·p95·최대(ms)와 평균 fps.
   할당 없는 고정 링 버퍼. `BattleGame.perf`로 노출(기존 `fps`·`stats`와 함께).
2. **부하 장면**(`stressRecording()`, render/demo/): 코드로 만드는 결정론적 기록 — 적 24마리 이상 화면 안(물위·공중·물속 섞음),
   0.5초마다 범위 처치(AoeDamageSum + Kill 다수), 치명타·궁극기·히트스톱 포함, 10초 길이 반복.
   `BattleGame.loadStress()` / `loadDemo()`로 전환(라이브 feed가 있으면 잠시 끊었다가 `resumeLive()`로 복귀).
3. **절전 30fps**: `settings.powerSave`이면 juice `powerSave.fps` 주기로만 장면을 진행하고 그림(Picture)을 새로 기록,
   그 사이 프레임은 직전 Picture를 다시 그린다(같은 화면, 그리기 비용 최소).
   언제 켤지(무입력 `powerSave.idleSec`)는 UI 레인이 정하고 렌더는 값만 받는다.
4. **정수배 확대**: 위젯 크기에서 `floor(min(w/320, h/180))`배(최소 1)로 그리고 남는 곳은 테두리 색. nearest라 도트가 번지지 않는다.
   (`withFixedResolution`의 비정수 배율을 대체.)
5. **측정 절차**(사람/S4, 실기기는 S4만 쓴다): `flutter run --profile --dart-define=OPERATOR=true` → 운영자 패널 "부하 장면" → 60초.
   합격: p95 ≤ 16.7ms, 최대 ≤ 33ms가 1초에 1회 이하. 결과는 `docs/progress/render.md`에 기기명과 함께 기록.

## 수용 기준 (Given / When / Then) — `apps/game/test/render/`
1. Given 프레임 시간 120개(알려진 분포) When `PerfMonitor` Then p50·p95·최대·fps가 계산값과 같다. 121번째부터 가장 오래된 값을 밀어낸다.
2. Given `stressRecording()` 두 번 When 비교 Then 같은 JSONL. 모든 틱에서 화면 안(x≤320) 적 ≥ 24, 10틱마다 AoeDamageSum이 있다.
3. Given 부하 장면 60초(60fps 프레임) When 재생 Then 매 프레임 이펙트 ≤ 40·숫자 ≤ 24, 워밍업(1회 반복) 뒤 `stats.pooledObjects` 불변.
4. Given 절전 켬 When 60Hz로 1초 Then 장면 갱신 ≤ 30회, 나머지 프레임은 같은 Picture를 다시 그린다.
5. Given 위젯 크기 (1080, 700)·(319, 200)·(1920, 1080) When 정수배 계산 Then 3·1·6배와 가운데 정렬 오프셋.
6. Given `loadStress()` 뒤 `resumeLive()` When 라이브 feed가 있음 Then 다시 feed를 재생하고 부하 장면 객체는 남지 않는다.

## 문구 (ko / en)
없음 — 운영자 패널 문구는 UI 레인(op ARB)이 `BattleGame.perf` 값을 표시한다.

## 운영자 모드에서 불러보는 법
UI 레인 운영자 패널: "부하 장면 / 데모 / 라이브" 전환, 히트박스(`showHitboxes`), 흔들림·번쩍임·절전 토글, fps·p95·이펙트 수 표시.
렌더는 `BattleGame.perf`·`stats`·`loadStress()`·`loadDemo()`·`resumeLive()`·`settings`만 제공한다.

## 열린 질문
- Q1. 정수배 확대를 렌더(Flame 뷰포트)에서 할지, UI가 위젯 크기를 정수배로 잡아 줄지 — 이 스펙은 렌더 쪽으로 가정(S4와 확인 필요).
