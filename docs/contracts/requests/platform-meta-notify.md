# platform → economy: `MetaTable.notificationsDailyMax` 파싱 (S1 중계 → S2)

- 요청 레인 / 날짜: platform(S5) / 2026-10-15 · `platform-notify-setting` "함께" 절을 따로 뗌 (S1 지시: 테이블 쪽은 요청서로)
- 바꿀 경로: economy 레인 소유 `packages/game_data/lib/src/models/economy_tables.dart`. 테이블 값(`meta.json` `"notifications": { "dailyMax": 1 }`)은 이미 있음.

## 왜 필요한가
main.dart가 `OfflineFullNotifier(dailyMax: 1)`을 하드코딩한다(`TODO(platform)`). 알림 횟수는 피로 규칙(설계서: 하루 1회)이라 테이블이 기준이어야 한다.

## 제안 (코드 스케치)
```dart
// MetaTable.fromJson 초기화 목록
      notificationsDailyMax = j.obj('notifications').integer('dailyMax'),

  /// 오프라인 가득 로컬 알림의 하루 최대 횟수 (울릴 현지 날짜 기준, platform OfflineFullNotifier).
  final int notificationsDailyMax;

// validate()
    expect(e, that: notificationsDailyMax >= 0 && notificationsDailyMax <= 1,
        message: 'meta: notifications.dailyMax는 0~1 (피로 금지 규칙: 알림 하루 1회)');
```
- 테스트(game_data): 실제 테이블에서 `notificationsDailyMax == 1`, 2면 validate 오류.

## 반영 뒤 main.dart (S1)
```diff
-    dailyMax: 1, // TODO(platform): meta.notifications.dailyMax 파싱 뒤 테이블 값
+    dailyMax: tables.meta.notificationsDailyMax,
```

## 그동안 쓰는 임시 어댑터
main.dart `dailyMax: 1` (테이블 값과 같음).

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
