# 스펙: 광고 버튼 · 오디오 포트 자리 (ui ↔ platform)

- 상태: 승인됨 (2026-10-14, S1 지시 — S5 요청서 platform-ui-ports가 오면 맞춘다) · 레인: ui · 설계서 절: 4.6 · 9.1

## 규칙
1. `adsPortProvider`(기본 `NoAds`: 준비 안 됨) · `audioPortProvider`(기본 null = 무음). 앱(main)·platform 레인이 실제 어댑터로 덮는다.
2. 광고 버튼은 `adOfferProvider(placement)`가 true일 때만 보인다 = 포트 `isReady` && 경제 `canWatchAd`(하루 한도) && 튜토리얼 아님. 로드 안 됐으면 버튼을 숨기고 기본 보상만(4.6).
3. 누르면 `AdsPort.show(placement)` → `AdResult.rewarded`일 때만 `GrantAdReward(placement, choice:)`. dismissed·failed·notLoaded면 아무것도 보내지 않는다(실패 후 보상 없음 같은 나쁜 경험 대신 버튼만 다시).
4. 버튼에는 항상 이득을 숫자로(4.6): 상자 ‘×5 · 1.25M’ / ‘젬 30’, 오프라인 ‘×2 · 4.82M’(`lastOfflineGold`가 있을 때, 복귀당 1회), 순풍 ‘30분 ×2’, 함포 지원 ‘피해 +30% · 30초’(보스 실패로 파밍 중), 무료 소환 ‘무료 소환 · 남은 N회’.
5. 오디오: `battleGameProvider`가 `BattleGame(audio: …)`로 넘기고, 설정 효과음·배경음 끄기를 `setVolumes(sfx: 0|1, bgm: 0|1)`로 반영.

## 수용 기준 — 위젯 테스트(가짜 AdsPort)
1. 기본(NoAds)이면 광고 버튼 0개(모든 장치).
2. 준비된 가짜 포트 + 상자 → ×5·젬 두 버튼, ×5 누름 → show(chest) → rewarded → `GrantAdReward(chest, choice: 'gold')`; dismissed면 명령 없음.
3. 오프라인 팝업: `lastOfflineGold` 있을 때만 ×2 버튼(금액 표시), 누름 → rewarded → `GrantAdReward(offline)`.
4. 순풍·함포 지원·무료 소환 버튼이 각 자리에 뜨고 rewarded → 해당 placement.
5. 튜토리얼 중이거나 경제 한도가 다 찼으면 숨김.
6. 설정 효과음 끄기 → 가짜 AudioPort.setVolumes(sfx: 0, …).
7. 이탈 분석: 탭을 배로 → `setLastSeen('ship', 37)`, 스테이지 38 → `('ship', 38)`.

## S5 요청서 반영 (`docs/contracts/requests/platform-ui-ports.md`)
- `adsPortProvider`·`audioPortProvider`·`analyticsPortProvider` — 기본 `NoAds`·null·`NoopAnalytics`(지금은 ui 임시 클래스, S5 어댑터가 main에 오면 그것을 import하고 ui 쪽은 지운다).
- 이탈 분석: 시작·탭 전환·스테이지 변경 때 `setLastSeen(screen: voyage|ship|crew|summon, stage)`.
- 알림 설정 토글(`platform-notify-setting.md`)은 `Settings.notifications`(세이브 v4, S1)가 오면 설정 화면에 추가.
