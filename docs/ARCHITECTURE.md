# 아키텍처

게임 규칙은 전부 `game_core`에 있고, 앱은 그 상태를 그리고 입력을 명령으로 바꿔 넘기기만 한다.
외부 세계(시계, 난수, 파일, 광고, 서버)는 포트 인터페이스로만 만나므로 테스트는 가짜를, 앱은 진짜 구현을 끼운다.

```
game_data ──▶ game_core ──▶ game_cli
                   │
                   └──────▶ apps/game ─ render/  (상태 읽기, 이벤트 → 연출)
                                       ─ ui/      (화면, 버튼 → Command)
                                       ─ adapters/(포트 구현: 저장·광고·분석·시계)
                                       ─ operator/(운영자 모드, kOperator 빌드에서만)
```
화살표 방향으로만 import한다. 거꾸로 가면 `tool/lib/src/deps.dart`가 실패시킨다.

## 의존 규칙

| 패키지 | import 허용 | 금지 |
| --- | --- | --- |
| `game_data` | `dart:core`, `dart:convert` | 나머지 전부 |
| `game_core` | `game_data`, `meta`, `collection`, `crypto`(ADR-0004), `dart:{core,async,collection,convert,math,typed_data}` | Flutter, `dart:io`, `dart:ui`, Flame, 플러그인 |
| `game_cli` | `game_core`, `game_data`, `dart:io`, `args`, `path`, `yaml` | Flutter |
| `apps/game` | 위 패키지의 공개 API (`game_core.dart`, `contracts.dart`, `testing.dart`, `game_data.dart`) | 다른 패키지의 `lib/src/` |

앱 내부: `render/`는 `ui/`·`adapters/`를 import하지 않고 명령을 내지 않는다. `adapters/`는 `ui/`·`render/`를 모른다.

## 포트

`packages/game_core/lib/src/ports/ports.dart`

| 포트 | 1차 구현 | 테스트 구현 (`testing.dart`) | 2차 |
| --- | --- | --- | --- |
| `Clock` | `adapters/system_clock.dart` | `ManualClock` | 서버 시간 보정 |
| `Rng` | `XorShiftRng` (코어, 시드 고정) | 같은 구현 | - |
| `SaveStore` | JSON 파일 (플랫폼 레인) | `MemorySaveStore` | 클라우드 백업 |
| `AdsPort` | AdMob 보상형 (플랫폼 레인) | `InstantAds` | - |
| `AnalyticsPort` | Firebase (플랫폼 레인) | `RecordingAnalytics` | - |
| `LeaderboardPort` | `NoopLeaderboard` | `MemoryLeaderboard` | Cloudflare Workers |
| `PurchasePort` | 없음 | - | IAP |

## 결정론적 시뮬레이션

- `GameEngine.tick()`은 `waves.json`의 `tickMs`(50ms, 20Hz)마다 한 번. 화면 프레임과 무관하고 렌더는 두 틱 사이를 보간한다.
- 입력은 `Command`로만 들어오고 **다음 틱**에 적용된다.
- 코어는 `GameState`(불변 스냅샷)와 `GameEvent`를 내보낸다. 효과음·숫자·파티클은 렌더가 이벤트를 보고 만든다.
- 히트스톱은 코어가 `HitStop(ticks)` 이벤트로 내보내고, 엔진이 그 틱 수만큼 시뮬을 멈춘다 → 리플레이 결과 불변.
- 난수는 `Rng` 하나뿐. 상태(`rngSeed`)는 세이브에 들어가 불러온 뒤에도 같은 수열이 이어진다.

## 엔진과 레인의 경계

`CoreEngine`(공유, main 전용)은 명령 큐·틱·히트스톱·배속·운영자 공통 명령(`OpSetSpeed`, `OpStepTick`, `OpLoadState`)·`SetSetting`만 처리한다.
게임 규칙은 `GameSystem` 구현 두 개에 들어간다:

| 시스템 | 위치 | 레인 | 담당 |
| --- | --- | --- | --- |
| `EconomySystem` | `game_core/lib/src/economy/` | economy (S2) | 강화·소환·카드·승급·광고 보상·환생·일일·오프라인 |
| `BattleSystem` | `game_core/lib/src/battle/` | battle (S1) | 무리·발사·스킬·궁극기·피해·보스·파밍 |

엔진은 명령을 시스템 순서(경제 → 전투)대로 넘기고, `null`이 아닌 상태를 돌려준 첫 시스템이 처리한 것으로 본다.
아무도 처리하지 않은 명령은 `CoreEngine.unhandled`에 남는다(테스트에서 확인).

## 데이터와 다국어

- 테이블 JSON(`packages/game_data/tables/`) → `tool/gen_tables.dart` → `lib/src/tables.g.dart`(const 문자열). `game_data`가 `dart:io`를 못 쓰기 때문(ADR-0003).
- `GameTables.load()`는 형식(`TableFormatException`, 경로 포함)과 값(`TableValidationException`)을 모두 검증한다.
- 테이블에는 문구 대신 l10n 키(`nameKey`)만. ARB 키는 Dart 식별자여야 하므로 `crewOctoName`처럼 camelCase + 레인 접두어.
- ARB 원본은 `apps/game/lib/l10n/parts/<레인>.<ko|en>.arb` → `tool/merge_arb.dart` → `merged/`(gitignore) → `flutter gen-l10n` → `gen/`(gitignore).

## 세이브

- `SaveCodec.encode/decode` — `schemaVersion` + 본문 + `checksum`(sha256, 손상 탐지용).
- `migrations[i]`는 v(i+1)→v(i+2) 순수 함수. 버전마다 `packages/game_core/test/fixtures/saves/v<N>.json`이 있어야 한다(테스트가 확인).
- `loadSave()` — 본 파일이 깨지면 `save.bak`으로 복구. 원자적 쓰기(`save.tmp` → rename)는 `SaveStore` 구현 책임.

## 전투 기록 (렌더 레인 입력)

`RecordedTick(frame: BattleView, events)` 한 줄 = 한 틱인 JSONL. `fixtures/events/sample_battle.jsonl`은 지금은 합성본이고,
전투 레인이 `game_cli export-events`를 구현하면 실제 엔진 출력으로 바뀐다. 렌더 레인은 이 파일만 보고 개발한다.
