# 스펙: 운영자 패널 1차

- 상태: 승인됨 (2026-10-14, S1) · 레인: ui · 설계서 절: 6.10

## 목적
- 단순한가: 테스트 기기에서 샘플 상태·배속·무적·보스·스테이지·자원을 버튼 하나로 바꿔 화면과 전투를 바로 시험한다.
- 공정한가: 스토어 빌드에는 코드가 없다(`kOperator` 상수 가드로 컴파일 때 빠짐). 운영자 표식은 엔진(OpLoadState 등 처리)이 남긴다.

## 규칙
1. 패널은 `apps/game/lib/operator/`에만 둔다. operator/ 밖에서 부를 때는 반드시 `if (kOperator) { ... }` 안에서만 부른다.
2. 모든 조작은 `commandSinkProvider`로 `OperatorCommand`만 보낸다. `gameStateProvider.replace`는 쓰지 않는다(엔진 상태가 기준).
3. 샘플 상태 불러오기: S1이 만드는 생성물 `apps/game/lib/operator/sample_states.g.dart`의 `sampleStatesJson`(키 4개: new_player · stage37_midgame · boss_fight · all_crews_mythic)을
   `GameState.fromJson(SaveCodec.migrate(jsonDecode(text)))`로 읽어 `OpLoadState(state)`를 보낸다. 앱 에셋은 쓰지 않는다.
4. 여는 법: 설계서는 “설정의 버전 글자 5번”인데 설정 화면이 아직 없다 → 1차에는 **HUD의 스테이지 글자를 5번 연속(2초 안) 누르면** 연다. 제스처는 `kOperator` 빌드에서만 등록한다(배포 빌드에는 제스처 자체가 없다). 설정 화면이 생기면 버전 글자로 옮긴다.
5. 패널은 하단 시트로 띄우되 HUD를 가리지 않는다(최대 높이 = HUD 아래까지). 열어 둔 채 전장이 보이게 한다.
6. 문구는 `parts/op.*.arb`(키 접두어 `op`), ko/en 둘 다.

## 패널 묶음 (1차)
| 묶음 | 버튼 | 보내는 명령 |
| --- | --- | --- |
| 저장 | 샘플 상태 4개 (이름 버튼) | `OpLoadState(state)` |
| 전장 | 배속 ×1 · ×2 · ×4 | `OpSetSpeed(1/2/4)` |
| 전장 | 무적 켜기/끄기 (스위치, 현재 값은 패널 안에서 기억) | `OpSetInvincible(on:)` |
| 전장 | 보스 즉시 소환 | `OpSpawnBoss()` |
| 전장 | 스테이지 이동 (숫자 입력 + 이동, 1 이상) | `OpJumpStage(n)` |
| 선원 | 쿨타임 0 켜기/끄기 (스위치) | `OpZeroCooldown(on:)` |
| 경제 | 골드 지급(1e6 · 1e12 · 1e30), 젬 +1000 | `OpGrant(gold:)` / `OpGrant(gems: 1000)` |

(선원 등급·레벨 지정, 비교, 타격감 슬라이더, 광고, 언어·긴 문장 모드, 세이브 내보내기는 2차)

## 수용 기준 (Given / When / Then) — 각각 위젯 테스트
1. Given 운영자 패널 When 샘플 `boss_fight` 버튼 Then `SaveCodec.migrate`를 거친 `OpLoadState` 1개가 가고, 그 state의 stage가 5다 (4개 샘플 모두 파싱 성공).
1-1. Given 엔진이 OpLoadState를 처리해 상태가 바뀌면(gameStateProvider 갱신) Then HUD·탭이 바로 새 상태(보스 타이머 등)를 보인다.
2. When 배속 ×2 Then `OpSetSpeed(2)`. ×1·×4도 같다.
3. When 무적 스위치를 켜고 끄면 Then `OpSetInvincible(on: true)` → `OpSetInvincible(on: false)`.
4. When 보스 소환 Then `OpSpawnBoss`.
5. When 스테이지에 `120` 입력 후 이동 Then `OpJumpStage(120)` / `0`이나 빈 값이면 이동 버튼 비활성.
6. When 쿨타임 0 스위치 Then `OpZeroCooldown(on: true)`.
7. When 골드 1e12 Then `OpGrant(gold: 1e12)` / 젬 +1000 Then `OpGrant(gems: 1000)`.
8. Given `kOperator == false`(기본 테스트 빌드) When HUD 스테이지 글자를 5번 누르면 Then 패널이 열리지 않는다.
   (`kOperator == true` 경로는 패널 위젯을 직접 띄워 1~7로 시험한다 — 상수라 테스트에서 바꿀 수 없다.)
9. 영어 골든 1장(패널, `stage37_midgame`).

## 문구 (ko / en) — `parts/op.*.arb`
| 키 | ko | en |
| --- | --- | --- |
| opPanelTitle | 운영자 모드 | Operator Mode |
| opGroupSave / opGroupBattle / opGroupCrew / opGroupEconomy | 저장 / 전장 / 선원 / 경제 | Save / Battle / Crew / Economy |
| opSampleNewPlayer / opSampleStage37 / opSampleBossFight / opSampleAllMythic | 새 플레이어 / 스테이지 37 / 보스전 / 모두 신화 | New Player / Stage 37 / Boss Fight / All Mythic |
| opSpeed | 배속 ×{speed} | Speed ×{speed} |
| opInvincible | 배 무적 | Invincible Ship |
| opSpawnBoss | 보스 소환 | Spawn Boss |
| opJumpStage / opJumpStageHint | 이동 / 스테이지 | Go / Stage |
| opZeroCooldown | 쿨타임 0 | Zero Cooldown |
| opGrantGold / opGrantGems | 골드 +{amount} / 젬 +{amount} | Gold +{amount} / Gems +{amount} |

## 운영자 모드에서 불러보는 법
- `flutter run --dart-define=OPERATOR=true` → HUD 스테이지 글자 5번 → 패널.

## 기다리는 것
- S1: `sample_states.g.dart` 생성물(allLanes 등록). 오기 전에는 테스트에서 `fixtures/states`를 읽는 임시 소스로 진행하고, 받으면 교체.

## 2차 (승인됨 2026-10-14, S1 — 전투 M3·메타 확인용)
| 묶음 | 버튼 | 보내는 명령 | 값의 출처 |
| --- | --- | --- | --- |
| 선원 | 출전 선원마다 ‘스킬: 이름’ | `OpCastSkill(crewId)` | `battle.fleet` |
| 선원 | 출전 전원 → 전설 첫 레벨 / 신화 첫 레벨 | 출전 선원마다 `OpSetCrew(id, level:)` | `rarities.json` legend·mythic의 levelMin (46·61) |
| 전장 | 보물상자 띄우기 | `OpSpawnChest()` | - |
| 경제 | 순풍 +30분 | `OpGrantTailwind(Duration)` | `ads.json` tailwind.durationSec |
| 튜토리얼 | 단계 1~6, 끝 | `OpSetTutorial(step)` / `OpSetTutorial(null)` | - |

### 2차 수용 기준
10. Given 출전 4명(stage37) Then 스킬 버튼 4개, 망타 스킬 → `OpCastSkill('manta')`.
11. ‘출전 전원 → 전설’ → 출전 선원마다 `OpSetCrew(id, level: 46)` (신화는 61). 레벨은 테이블에서 읽는다.
12. 보물상자 → `OpSpawnChest`, 순풍 → `OpGrantTailwind(30분)`, 튜토리얼 3 → `OpSetTutorial(3)`, 끝 → `OpSetTutorial(null)`.
13. 패널 골든 갱신.
