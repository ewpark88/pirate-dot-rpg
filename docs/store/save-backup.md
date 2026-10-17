# 세이브 백업·기기 교체 — 지금 범위와 다음 단계

- 2026-10-18, S5 · 요청: S1(사용자 '클라우드 저장 백업이 없어 기기를 바꾸면 진행을 잃는다').
- 근거: 코드(`apps/game/lib/main.dart`·`adapters/file_save_store.dart`·`android/app/src/main/AndroidManifest.xml`), Android 공식 자동 백업 동작(Auto Backup for Apps).

## 1. 지금 세이브가 있는 곳
| 파일 | 위치 | 비고 |
| --- | --- | --- |
| `save.json` · `save.bak` · `save.bak2` | 앱 지원 폴더(`getApplicationSupportDirectory` = Android `files/`) | 원자적 쓰기(save.tmp → rename), 백업 2개 |
| `operator_backup/` | 같은 폴더 아래 | 운영자 빌드만 |

## 2. Android 자동 백업(지금 켜져 있음 — 별도 설정 없음)
- 매니페스트에 `allowBackup`·`fullBackupContent`·`dataExtractionRules`가 없다 → **기본값: 켜짐**, `files/`(세이브 포함)이 백업 대상이다(`cache/`·`no_backup/` 제외, 앱당 25MB 상한 — 세이브는 수십 KB).
- 백업 시점: 기기가 쉬는 중·충전 중·Wi-Fi일 때 하루 한 번 정도(OS가 정함). **마지막 백업 뒤의 진행은 빠질 수 있다.**
- 복원: 같은 Google 계정으로 **새 기기를 설정하면서 백업에서 복원**하거나, 같은 기기에 다시 설치할 때 OS가 자동으로 넣는다. 사용자가 기기 설정에서 'Google 백업'을 꺼 두었으면 없다.
- 개발자는 백업 내용을 볼 수 없다(사용자 Google 계정 안) — 개인정보처리방침 1항에 이미 적음.
- 결정 필요 없음(유지 권장, `data-safety.md` 4절 2).

## 3. 이번에 넣은 것: 세이브 옮기기 코드(review/save-transfer)
- 설정 화면용(운영자 아님): 지금 세이브를 글자 코드로 **내보내기**, 새 기기에서 붙여 넣어 **가져오기** — 서버 없이(메모·메신저·이메일로 옮김).
- 형식: `PDX1.` + base64url(gzip(세이브 JSON)) — 세이브 JSON은 `SaveCodec` 그대로라 **sha256 체크섬·버전 마이그레이션**이 함께 온다. 한 글자라도 바뀌면 가져오기 실패(SaveCorruptException), 공백·줄바꿈은 무시.
- 가져오면 `EngineHost.replace`로 엔진을 바꾸고 바로 저장(savedAt = 지금 — 옮기는 동안 오프라인 보상이 쌓이지 않게). 진행 중이던 장면(현상금·탑 등)은 새 엔진 첫 틱에 '중단'으로 정리.
- UI(S4): `saveImportProvider`(가져오기 함수) + `SaveTransfer.export(state)`(코드 만들기) — 설정에 '세이브 옮기기' 칸: 코드 복사·붙여 넣기·확인 창(덮어쓰기 경고).
- 한계: 코드는 길다(신화 상태 기준 수 KB) — 복사·붙여 넣기 전제. 같은 코드를 여러 기기에 쓰면 진행이 둘로 갈라진다(막지 않음 — 서버가 없어서).

## 4. 다음 단계 제안: Google Play Games 저장(Saved Games)
| 항목 | 내용 |
| --- | --- |
| 무엇 | Play Games 계정에 세이브 스냅샷(최대 3MB)을 올리고 다른 기기에서 받는다 — 자동 백업보다 즉시·확실 |
| 필요 | Play Games Services 설정(사람: Play 콘솔 게임 서비스·OAuth 클라이언트·SHA-1), 플러그인(예: `games_services` — 무료, 버전은 그때 2주 넘은 안정판), 로그인(자동 로그인 v2) |
| 엔진 | 지금 SaveStore 포트에 '원격' 하나를 더하면 된다(로컬 저장 뒤 몇 분에 한 번·백그라운드 갈 때 올림, 시작 때 원격이 더 앞서면 묻고 가져오기) — 충돌 규칙: savedAt·bestStage·환생 수 비교 |
| 데이터 보안 | 'Play Games가 처리' — 수집 항목은 Google 쪽, 양식 답 다시 확인 |
| 랭킹(M6)과 | 같은 Play Games 연동이라 M6 랭킹과 묶어 하는 게 효율적 |
- 권장: 지금은 자동 백업 + 옮기기 코드로 '잃지 않는 길'을 두 개 두고, Play Games 저장은 M6 랭킹과 함께(사용자 결정).
