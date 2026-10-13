# 레인: 플랫폼 (platform) — S2, 2단계(M3~M5)

- 브랜치: `lane/platform` · 진척: `docs/progress/platform.md`
- 소유 경로: `LANES.yaml` → `lanes.platform.paths` (`adapters/`, `android/`, `ios/`, `.github/`, `docs/store/`)
- 설계서: 3.2 포트, 5.2 세이브, 8장 랭킹 포트, 9장 수익화·규정

## 할 일
1. `SaveStore` 파일 구현: `path_provider`, `save.tmp` → rename, `save.bak` 보관, 저장 시점(이벤트 `SaveRequested`, 백그라운드, 10초)
2. `AdsPort` AdMob 보상형 + UMP(→ ATT), 테스트 광고 ID, 로드 안 되면 버튼 숨김
3. `AnalyticsPort` Firebase Analytics + Crashlytics (마지막 화면·스테이지·막힌 시간)
4. 로컬 알림(오프라인 8시간 가득, 하루 1회)
5. CI: Android 내부 테스트 빌드, 배포 빌드에 운영자 코드가 남으면 실패하는 검사, Codemagic iOS(릴리스 태그만)
6. 스토어 문구 ko/en, 개인정보처리방침·app-ads.txt(GitHub Pages)

## 완료 기준
- 저장·복원 통합 테스트(앱 실행 → 전투 1분 → 저장 → 재실행 복원), 광고 테스트 ID, Android 내부 테스트 빌드
