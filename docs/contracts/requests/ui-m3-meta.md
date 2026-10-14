# 요청: M3 메타 화면에 필요한 계약·세이브·경제 (ui → S1·S2)

- 요청 레인: ui (S4) · 날짜 2026-10-14 · 스펙: `docs/specs/ui-m3-meta.md`
- 원칙: 화면은 `GameState`만 구독한다. 화면에 오래 남는 것(떠 있는 상자·튜토리얼 단계·받았는지)은 상태에 있어야 한다. 이벤트는 연출용.

## A. 계약·세이브 (S1 — 세이브 v3 + 마이그레이션 + 픽스처)
| # | 무엇 | 제안 | 쓰는 곳 |
| --- | --- | --- | --- |
| A1 | 떠 있는 보물상자 | `GameState.chest: ChestState?` = `{x, y, expiresAt}` (세이브엔 없어도 됨 → BattleView에 둬도 된다) | ② |
| A2 | 일일 퀘스트 보상 받았나 | `DailyState.questsClaimed: bool` | ④ |
| A3 | 출석 오늘 받았나 | `DailyState.attendanceClaimed: bool` (date 바뀌면 false) 또는 `lastAttendanceDate` | ④ |
| A4 | 튜토리얼 단계 | `GameState.tutorialStep: int?` (1~6, 끝·건너뜀 = null). 새 게임 = 1, v2→v3 마이그레이션 = null(기존 플레이어) | ⑥ |
| A5 | 튜토리얼 명령 | `SkipTutorial()`, `TutorialAck(step)`(UI 동작으로 끝나는 단계: ‘소환 결과 닫기’) | ⑥ |
| A6 | 운영자 명령 | `OpSpawnChest()`, `OpSetTutorial(step?)`, 순풍 부여(`OpGrant`에 `tailwindSec` 또는 `OpSetTailwind(sec)`) | 패널 |

## B. 경제 규칙·함수 (S2 — `game_core.dart`로 공개)
| # | 함수/규칙 | 반환·설명 | 쓰는 곳 |
| --- | --- | --- | --- |
| B1 | `NextGoal? nextGoal(GameState, GameTables)` | `{kind: shipTier/partMilestone/collection/rebirth, id?, remaining, progress 0~1}` 가장 가까운 것 하나 | ① |
| B2 | 상자 스폰·가라앉기·하루 한도 | `ads.json` chest(intervalSec 240, floatSec 40, dailyLimit 10). 첫 상자는 `firstOfferAfterSec` 뒤, 튜토리얼 중 없음 | ② |
| B3 | `TapChest` 처리 + `BigNum chestReward(GameState, GameTables)` | 기본 보상(baseGoldSec × 초당 골드) 미리보기 | ② |
| B4 | `GrantAdReward(chest/tailwind/freeSummon/bossSupport)` 처리 | ads.json 보상·한도·하루 총 25 | ②③ (광고 포트 뒤) |
| B5 | `Duration tailwindRemaining(GameState, DateTime now)` | 0 이하는 zero, 최대 누적 반영 | ③ |
| B6 | 퀘스트 진행 집계 | kill/upgrade/summon/ad를 `daily.quests`에 더함, 날짜 바뀌면 초기화(Clock) | ④ |
| B7 | `List<QuestView> dailyQuests(GameState, GameTables)` + `bool canClaimDaily(...)` + `ClaimDaily` 처리 | `{id, type, progress, target, done}`, 4개 다 하면 젬 40 | ④ |
| B8 | `AttendanceView attendance(GameState, GameTables, DateTime now)` + `ClaimAttendance` 처리 | `{day 1~7, claimedToday, rewards[7]}` — 테이블에 1~6일차 보상이 없다 → `meta.attendance.rewards` 추가 필요 | ④ |
| B9 | `CollectionBonus collectionBonus(GameState, GameTables)` | `{owned, total, attackBonus, nextAt}` (every 5, +3%) | ⑤ |
| B10 | 튜토리얼 단계 판정 | 대포 Lv3 → 3단계, 스테이지 3 보스 ‘일부러 실패’(전투 S1), 강화 2번 후 도전, 첫 10연 영웅 확정(이미 `firstTenGuarantee`), 일괄 합치기 1번 | ⑥ |

## UI가 그동안 하는 것
- 각 기능을 가짜 provider로 화면·테스트를 먼저 만들고, 함수가 오면 provider 본문만 바꾼다(오프라인 팝업과 같은 방식).
- 광고 버튼은 자리·숨김만. 튜토리얼 손가락은 위젯 키로 가리킨다(`ship.upgrade.cannon`, `boss.challenge`, `summon.ten`, `crew.mergeAll`).
