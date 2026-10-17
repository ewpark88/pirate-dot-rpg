# 크래시·ANR 대비 점검 (첫 출시 전)

- 2026-10-18 · S5 · 요청: S1. 근거: 코드(main 9814ce91 — `adapters/analytics/firebase_sdk.dart`·`sdk_analytics.dart`·`file_save_store.dart`·
  `engine_host.dart`·`render/hd/hd_sheets.dart`·`main.dart`), 기기 감시(`device/device_watch.py` — 10/17~18 표본).
- Play 콘솔 '안드로이드 바이탈' 나쁨 기준: 사용자 감지 비정상 종료율 1.09%, ANR 0.47% 넘으면 노출 불이익.

## 1. 지금 잡히는 것
| 종류 | 어디 | 상태 |
| --- | --- | --- |
| Dart 치명 오류(위젯 build·프레임) | `firebase_sdk.dart` `FlutterError.onError = recordFlutterFatalError` | 배포 빌드만(`collectCrashes`) ✓ |
| Dart 비동기 미처리 예외 | `PlatformDispatcher.instance.onError → recordError(fatal: true)` | 배포 빌드만 ✓ |
| 네이티브(Java/Kotlin·NDK) 크래시 | Crashlytics 플러그인 기본 | ✓ (NDK 심볼은 업로드 설정 확인 필요 — `firebase.md`) |
| 크래시 보고서 키 | `sdk_analytics.dart` `screen`·`stage` | ✓ — 장면 모드·피버·적 수는 없음(아래 3) |
| ANR | Play 바이탈이 자동 수집 | Crashlytics엔 안 옴 — 콘솔에서 봄 |

## 2. 빠져 있는 것 (위험 순)
1. **비치명 오류가 하나도 안 간다.** 잡은 예외 9곳(`on Object catch` — 광고 4·전원 채널·알림·세이브·오디오·분석)은 `debugPrint`만 → 실기기에서 조용히
   기능이 꺼져도 모른다(예: 10/17 효과음이 영영 안 나던 버그). → `AnalyticsSdk.recordNonFatal(e, s, reason)` 하나 두고 9곳에서 부르기.
   같은 사유는 세션당 1회(로그 폭주 방지).
2. **세이브 실패.** `file_save_store.dart`는 실패를 `store.failure`로 UI에 알리지만 보고는 없음 → 세이브 실패는 비치명 + 키 `save_fail_count`.
3. **보고서 맥락 부족.** 키 추가 후보: `scene`(tower/rush/dungeon/bounty/없음) · `fever`(0/1) · `enemies`(동시 적 수 버킷) · `build`(APP_VERSION) ·
   `thermal`(전원 채널 단계). 틱마다가 아니라 바뀔 때만 set.

## 3. ANR 의심 지점 (UI 스레드·플랫폼 스레드를 오래 막는 것)
| 지점 | 얼마나 | 판단 |
| --- | --- | --- |
| 엔진 틱(전투 계산)이 UI 아이솔레이트에서 `Timer.periodic` | PC 평균 2ms·최대 8~44ms(피버 390~520마리, 10/18 탐침) → 폰 ×3~5 | ANR(5초)은 아님, **프레임 끊김** 위험 — 피버 상한 390 권장(S2에 보냄) |
| HD 시트 첫 굽기 `toImageSync`(`hd_sheets.dart`) | 종이 처음 보일 때 한 번, 큰 보스는 수십 ms | ANR 아님, 첫 등장 프레임 끊김 — 해역 진입 때 미리 굽기 후보(S3) |
| 세이브 `SaveCodec.encode`(JSON + sha256) 10초마다·이벤트마다 | 세이브 수 KB → 1ms 안 | 괜찮음 |
| `existsSync`(세이브 백업 회전) | 파일 stat 몇 번 | 괜찮음(비동기 쓰기 사이) |
| 시작: Firebase·광고(UMP)·오디오 목록 | 오디오는 `_sdkTimeout`으로 끊음, 단계별 logcat `boot:` | 광고·UMP 초기화가 네트워크를 기다리면 첫 화면이 늦음 — 이미 비동기, 확인만 |
| 결제·광고 콜백(플랫폼 메인 스레드) | 플러그인 내부 | Play 결제 연결이 끊긴 기기에서 재연결 반복 — 바이탈에서 지켜볼 것 |
| 뒤로 두 번 종료 직전 저장(`exitSaveProvider`) | 저장 await 후 종료 | 저장이 느린 기기에서 종료가 늦어 보일 수 있음 — 타임아웃 1초 권장 |

## 4. 출시 전 할 일
- [ ] (S5) `recordNonFatal` + 9곳 연결 + 키 5개 — 작게, 시험(가짜 SDK로 사유·1회 제한).
- [ ] (S5) 종료 저장 타임아웃 1초.
- [ ] (사람) Crashlytics 대시보드에서 테스트 크래시 1건 확인(운영자 빌드 '강제 크래시'는 배포 빌드에 없음 — 내부 테스트 트랙 빌드로).
- [ ] (사람) Play 콘솔 바이탈 알림 켜기(비정상 종료·ANR 나쁨 기준).
- [ ] (S3) 해역 진입 때 HD 시트 미리 굽기 검토.
- 기기 감시(`device_watch.py`)를 내부 테스트 동안 켜 두면 크래시 줄(우리 앱만)·끊김·온도를 표로 남긴다.
