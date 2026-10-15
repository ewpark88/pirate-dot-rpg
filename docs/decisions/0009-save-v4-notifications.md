# ADR-0009: 세이브 v4 — 설정 `notifications`

- 날짜: 2026-10-15 · 상태: 채택 · 요청: `docs/contracts/requests/platform-notify-setting.md` (platform S5)

## 결정
- `Settings.notifications`(bool, 기본 true): 오프라인 보상 가득 로컬 알림 켜기/끄기. `SetSetting('notifications', bool)`로 바꾼다.
- 마이그레이션 v3→v4: `settings.notifications = true` (기존 세이브는 켜짐).
- main.dart가 `OfflineFullNotifier(enabled:)`에 이 값을 넘기고, 바뀌면 `onSettingChanged`로 남은 예약을 즉시 취소한다.
- 설정 화면 토글은 ui 레인.

## 결과
- 픽스처 `test/fixtures/saves/v4.json` 추가(v3을 코덱으로 올려 다시 씀), v1~v3은 마이그레이션 검증용으로 유지.
