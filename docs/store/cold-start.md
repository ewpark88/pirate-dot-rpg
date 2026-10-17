# 콜드 스타트 → 첫 전투 프레임 (목표 2초 이하)

- 2026-10-18 · S5 · 요청: S1. 근거: `apps/game/lib/main.dart`(main fc6d0bea), PC 측정(아래 1), 폰 실측은 폰 연결 뒤.

## 1. 단계 (runApp 앞에서 순서대로 기다리던 것)
| 단계 | logcat `boot:` | PC 측정(JIT, 첫 실행 / 데운 뒤) | 폰 예상 | 비고 |
| --- | --- | --- | --- | --- |
| Flutter 엔진·첫 Dart | `start` | — | 300~600ms | 엔진 몫, 우리가 못 줄임(스플래시가 가림) |
| 화면 방향 고정 | `orientation` | ~0 | 수 ms | 플랫폼 호출 |
| 표 파싱 `GameTables.load` (131KB JSON 15장 + 검증) | (`supportDir`에 포함) | 121ms / 11ms | 40~120ms | 아래 3 후보 |
| 지원 폴더 `getApplicationSupportDirectory` | `supportDir` | — | 10~30ms | 플랫폼 호출 |
| 세이브 로드·해독 (4KB, sha256) | `loadSave` | 1ms 안 | 수 ms | 괜찮음 |
| 엔진 생성 + 첫 틱 | — | 126ms(JIT) | 30~80ms | runApp 뒤 타이머로 돈다 |
| **Firebase 초기화(분석·Crashlytics)** | `analytics` | — | 200~800ms, **최대 3초(타임아웃)** | **→ runApp 뒤로 옮김** |
| **음원 목록(AssetManifest)** | `audio` | — | 50~200ms, **최대 3초** | **→ 기다리지 않음** |
| 광고·UMP | (첫 프레임 뒤) | — | 네트워크 | 이미 첫 프레임 뒤 |
| HD 몬스터·배 첫 굽기 `toImageSync` | — | — | 종마다 수십 ms | 처음 보일 때 — 첫 전투 프레임에 몰림(아래 3, S3) |

## 2. 이번에 바꾼 것 (review/cold-start)
- `DeferredAnalytics`: 분석을 바로 쓰는 껍데기 — Firebase는 `runApp` 뒤에 시작해 붙고, 그 전 호출(이벤트·크래시 키·수집 동의)은 순서대로 쌓았다
  붙는 순간 보낸다(최대 200개). 비치명 보고 연결도 그때.
  - 대가: Firebase가 붙기 전(첫 1초 안팎)의 Dart 치명 오류는 Crashlytics에 안 간다(logcat엔 남음). 출시 뒤 바이탈로 지켜본다.
- `AudioAdapter.later`: 음원 목록을 기다리지 않고 바로 만든다 — 목록이 오기 전엔 무음, 오면 그 사이 정한 배경음·환경음을 튼다.
- `boot: firstFrame` 로그(첫 프레임이 그려진 시각) + `boot: analytics`(붙은 시각).
- 결과(예상): runApp 앞 대기에서 최대 6초(타임아웃 두 개) → 0, 평소 0.3~1초 단축.

## 3. 남은 후보 (큰 것부터)
1. **HD 첫 굽기를 첫 프레임 뒤로·나눠서**(S3 render): 첫 전투 화면에 보이는 종을 첫 프레임 뒤 한 프레임에 하나씩 굽고, 그 전엔 작은 대체 그림.
2. **표 파싱을 아이솔레이트로**: `Isolate.run(GameTables.load)`을 지원 폴더·세이브 로드와 동시에 — 폰에서 40~120ms 절약 예상.
   표 객체는 순수 Dart라 넘길 수 있지만 표 안 `Expando` 캐시(데이터 클래스에 없음)·`late` 필드 확인 필요. 실측해서 50ms 넘을 때만.
3. 폰트: 도트 폰트 에셋이 크면 첫 글자 그릴 때 로드 — 지금은 번들 폰트 2종, 실측 뒤 판단.
4. 엔진 첫 틱의 무리 생성(밀도 ×1.3 이후 마리 수 증가) — 첫 프레임에 안 보이는 적은 다음 틱으로 미루기(필요하면).

## 4. 폰 실측 방법 (읽기 전용 — 실행은 사람/S1이)
- 앱을 완전히 종료한 뒤(최근 앱에서 닫기) 실행 → `adb logcat -d -s flutter | grep "boot:"` — `start`부터 `firstFrame`까지 ms.
- 여러 번(5회) 재서 가운데값. 첫 설치 직후 1회는 따로(셰이더·파일 캐시가 비어 더 느림).
- 목표: `firstFrame` ≤ 2000ms(가운데값). 넘으면 위 3의 1·2 순서로.
