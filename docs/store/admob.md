# AdMob 설정 (사람 할 일, M5)

지금은 **Google 공식 테스트 ID만** 쓴다(실제 광고·수익 없음, 계정 정지 위험 없음). 스펙: `docs/specs/platform-m4.md` a.

| 무엇 | 지금(테스트) | 위치 |
| --- | --- | --- |
| Android 앱 ID | `ca-app-pub-3940256099942544~3347511713` | `apps/game/android/app/src/main/AndroidManifest.xml` |
| iOS 앱 ID (M6) | `ca-app-pub-3940256099942544~1458002511` | `apps/game/ios/Runner/Info.plist` |
| 보상형 단위 ID | Android `…/5224354917`, iOS `…/1712485313` | `apps/game/lib/adapters/ads/ad_unit_ids.dart` |

## M5에 할 일
1. https://admob.google.com → 앱 추가(Play 등록 뒤 연결) → 앱 ID 복사.
2. 광고 단위: **보상형 1개**(모든 장치가 공유 — chest·tailwind·offline·bossSupport·freeSummon).
3. 개인정보 및 메시지 → **GDPR 동의 메시지**(UMP) 만들기·게시. (없으면 EU 기기에 동의 창이 안 뜨고 광고가 안 나온다.)
4. ID 교체는 platform 레인에 요청(테스트 `admob_ads_test.dart`가 테스트 ID를 고정하고 있어서, 배포용 ID는 빌드 설정으로 분리하는 작업이 함께 필요).
5. `app-ads.txt`를 개발자 웹사이트(GitHub Pages)에 게시 — Play 스토어 등록정보의 웹사이트와 같은 도메인.
6. 실기기 테스트는 테스트 ID 또는 AdMob의 "테스트 기기" 등록으로만. 자기 광고를 실제로 누르지 않는다.
