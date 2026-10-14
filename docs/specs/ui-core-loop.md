# 스펙: 코어 루프 화면 — 보스 도전 · 복귀 오프라인 보상 · 설정 · 운영자 렌더 묶음

- 상태: 승인됨 (2026-10-14, S1) · 레인: ui · 설계서 절: 4.1-4 · 4.6 · 4.7 · 4.9 · 4.12(설정)

## 목적
- 단순한가: 막혔을 때 누를 것은 ‘보스 도전’ 하나. 복귀하면 받을 것은 팝업 하나.
- 피로가 없는가: 팝업은 접속(시작·복귀) 때 오프라인 보상 1개뿐. 흔들림·번쩍임·진동은 설정에서 끈다.
- 공정한가: 오프라인 금액은 받기 전에 숫자로 보이고, 받는 값과 같은 함수로 구한다.

## 규칙
1. 모든 조작은 `Command`만 보낸다: `ChallengeBoss`, `ClaimOffline`, `SetSetting(key, value)`.
2. 계산식은 UI에 두지 않는다. 오프라인 미리보기는 경제 함수(아래 “요청”)로 구한다.
3. 시간은 `clockProvider`(UI 레인 새 provider, 기본 `SystemClock`, 테스트는 고정 시계)로 읽는다.
4. 문구는 `parts/ui.*.arb`(ko/en).

### ① 보스 도전 (4.1-4)
- `progress.farming == true`이면 전장 위 오른쪽 위에 ‘파밍 중’ 표시와 **보스 도전** 버튼 → `ChallengeBoss`.
- 보스전 중(`battle.bossActive`)이거나 파밍이 아니면 둘 다 없다.

### ② 복귀 오프라인 보상 팝업 (4.7, 4.9)
- 앱 시작 직후 첫 프레임과 백그라운드에서 돌아올 때(`AppLifecycleState.resumed`) 한 번 미리보기를 구한다.
  미리보기가 있으면(최소 시간 이상) 팝업 1개: 경과 시간(최대 8시간 표시), 골드(`BigNum.format`), 카드 수, **받기** → `ClaimOffline` 후 닫힘.
- 팝업이 이미 떠 있으면 또 띄우지 않는다. 바깥 탭으로 닫히지 않는다(받기만).
- 광고 ×2 버튼은 광고 포트가 생길 때까지 숨긴다(4.6: 로드 안 되면 숨김).

### ③ 설정 화면 (4.12)
- HUD 오른쪽 톱니 아이콘 → 설정 화면(전체 화면 페이지, 뒤로 가기).
- 항목: 언어(시스템·한국어·English), 배경음, 효과음, 진동, 흔들림, 번쩍임, 절전 모드, 자동 보스 도전, 자동 강화. 바꾸면 `SetSetting(key, value)`.
- 앱 언어는 `settings.lang`을 따른다(`system`이면 OS 언어).
- 흔들림·번쩍임·진동·절전은 `JuiceSettings`로 바꿔 전장에 넘긴다(`BattleGame.settings` 공개 setter — 렌더 변경 없음).
- 크레딧·버전 글자는 다음 계획(버전 글자가 생기면 운영자 열기를 그리로 옮긴다).

### ④ 운영자 패널 ‘렌더’ 묶음 (6.10 전장)
- home_screen이 만든 `BattleGame`을 UI 레인의 `battleGameProvider`(`StateProvider`류, home_screen이 만들 때 등록·dispose 때 해제)로 노출한다. 렌더 코드는 바꾸지 않는다.
- 패널 버튼: 모드 라이브 / 데모 / 부하(`resumeLive()` / `loadDemo()` / `loadStress()`, 현재 `mode` 표시), 성능 오버레이(`perfOverlay`), 히트박스(`showHitboxes`) 스위치.
- 전장이 없으면(테스트의 빈 상자 등) 렌더 묶음은 비활성.

## 수용 기준 (Given / When / Then) — 각각 위젯 테스트
1. Given `farming = true` Then ‘보스 도전’ 버튼과 ‘파밍 중’이 보이고, 누르면 `ChallengeBoss` 1개.
2. Given `farming = false` 또는 보스전 중 Then 보스 도전 버튼이 없다.
3. Given `savedAt`이 고정 시계보다 2시간 전 When 앱 시작 Then 팝업 1개에 경과 2시간·미리보기 골드·카드 수가 보이고, 받기 → `ClaimOffline` 1개, 팝업 닫힘.
4. Given 경과가 최소 시간 미만 Then 팝업이 없다.
5. Given 팝업이 떠 있을 때 When 복귀 이벤트가 또 오면 Then 팝업은 여전히 1개.
6. Given 경과 20시간 Then 표시는 8시간(최대)으로 잘린다 (미리보기 함수 결과 그대로).
7. When 톱니 → 설정 Then 9개 항목이 보이고, 흔들림 스위치를 끄면 `SetSetting('shake', false)`.
8. When 언어를 English로 Then `SetSetting('lang', 'en')`, Given `settings.lang = 'en'`(한국어 OS) Then 화면이 영어.
9. Given `settings.shake = false` Then 전장에 넘긴 `JuiceSettings.shake == false` (흔들림·번쩍임·진동·절전 4개).
10. Given 등록된 BattleGame When 운영자 패널 ‘부하’ Then `mode == BattleMode.stress`, ‘라이브’ Then `resumeLive` 결과 모드, 오버레이·히트박스 스위치가 BattleGame 값을 바꾼다.
11. Given BattleGame이 없음 Then 렌더 묶음 버튼은 비활성.
12. 영어 골든 2장: 오프라인 팝업, 설정 화면.

## 문구 (ko / en)
| 키 | ko | en |
| --- | --- | --- |
| uiBossChallenge | 보스 도전 | Challenge Boss |
| uiFarming | 파밍 중 | Farming |
| uiOfflineTitle | 돌아오신 걸 환영해요! | Welcome back! |
| uiOfflineElapsed | {hours}시간 {minutes}분 동안 | While you were away: {hours}h {minutes}m |
| uiOfflineClaim | 받기 | Claim |
| uiSettingsTitle | 설정 | Settings |
| uiSettingsLanguage / uiLangSystem / uiLangKo / uiLangEn | 언어 / 시스템 / 한국어 / English | Language / System / 한국어 / English |
| opGroupRender / opModeLive / opModeDemo / opModeStress / opPerfOverlay / opHitboxes | 렌더 / 라이브 / 데모 / 부하 / 성능 표시 / 히트박스 | Render / Live / Demo / Stress / Perf Overlay / Hitboxes |
| uiSettingsBgm / uiSettingsSfx / uiSettingsVibration / uiSettingsShake / uiSettingsFlash / uiSettingsPowerSave / uiSettingsAutoBoss / uiSettingsAutoUpgrade | 배경음 / 효과음 / 진동 / 흔들림 / 번쩍임 / 절전 모드 / 자동 보스 도전 / 자동 강화 | Music / Sound Effects / Vibration / Screen Shake / Flash / Power Saving / Auto Boss / Auto Upgrade |

(언어 이름 “한국어”·“English”는 두 ARB 모두 같은 글자)

## 운영자 모드에서 불러보는 법
- 파밍: 운영자 패널 샘플/스테이지 이동 후 보스 실패, 오프라인: `OpAdvanceClock`(2차 패널 버튼) → 복귀 팝업.

## 요청 (경제 레인, S1 중계)
- `OfflinePreview? offlinePreview(GameState s, GameTables t, DateTime now)` → `{seconds, gold, cards}`. `claimOffline`과 같은 계산(경과 자르기·골드·카드 수, 난수 없음).
  최소 시간(`meta.offline.minSec`, 예: 60초) 미만이면 null. 오기 전에는 화면만 만들고 테스트는 가짜 미리보기 provider로 한다.
- 확인됨: main d6722b6의 `EngineHost.pause()`·`resume()`이 savedAt을 멈춘 시각으로 맞춘다 → 복귀 팝업은 resume 뒤 첫 프레임에 미리보기를 구한다.
