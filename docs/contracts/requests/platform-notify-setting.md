# platform: 설정 `Settings.notifications` (알림 켜기/끄기)

- 요청 레인 / 날짜: platform(S5) / 2026-10-14 · 스펙 `docs/specs/platform-m4.md` b.3
- 바꿀 계약: `Settings`(state_parts.dart)에 필드 1개, `SetSetting('notifications', bool)` 허용 → 세이브 v4(S1이 다른 필드와 묶어서)

## 왜 필요한가
오프라인 보상 가득 알림(하루 1회)을 설정에서 끌 수 있어야 한다(설계서 피로 원칙). 지금 설정에 해당 키가 없다.

## 제안 (코드 스케치)
```dart
class Settings {
  const Settings({ ..., this.notifications = true });
  /// 오프라인 보상 가득 로컬 알림 (platform). 기본 켜짐.
  final bool notifications;
}
// fromJson: notifications: j['notifications'] as bool? ?? true  — 또는 v3→v4 마이그레이션에서 true 채움
```
- 설정 화면 토글(ui 레인): 문구 키는 ui 접두어로 ui가 정한다(예: `uiSettingsNotifications` 알림 / Notifications).
- 끄면 platform 어댑터가 남은 예약을 즉시 취소해야 하므로, main.dart에서 `gameStateProvider.select((s) => s.settings.notifications)`를
  listen → `notifier.onSettingChanged(v)` 한 줄(머지 때 함께).

## 함께: `MetaTable.notificationsDailyMax`
`meta.json`의 `"notifications": { "dailyMax": 1 }`이 `MetaTable`(game_data, economy_tables.dart)에 파싱되지 않는다 →
`notificationsDailyMax = j.obj('notifications').integer('dailyMax')` 필드 1개. 그동안 main.dart가 `dailyMax: 1`을 넘긴다.

## 그동안 쓰는 임시 어댑터
`OfflineFullNotifier(enabled: () => true)` — 항상 켜짐.

## 처리 결과 (S1 작성)
- [x] 반영 (2026-10-15, S1) — 세이브 v4 ADR-0009, main.dart enabled·onSettingChanged 연결. 설정 토글은 ui(S4).
