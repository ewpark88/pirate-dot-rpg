# 앱 크기 — aab 내역과 줄이기

- 2026-10-18 · S5 · 요청: S1(aab 68MB, 목표 −20%). 분석 대상: `apps/game/build/app/outputs/bundle/release/app-release.aab`(10/16 빌드, 61.7MB 압축).
- 측정 도구: Python zipfile(aab = zip), fontTools 4.67(무료), Pillow.

## 1. aab 안 (압축 크기)
| 덩어리 | MB | 사용자에게 내려가나 |
| --- | --- | --- |
| BUNDLE-METADATA 네이티브 디버그 심볼(libflutter·libapp ×3 ABI) | 26.1 | **아니오** — Play가 크래시 기호용으로만 보관 |
| BUNDLE-METADATA 난독화 맵(proguard.map) | 3.9 | 아니오 |
| lib/x86_64 · arm64-v8a · armeabi-v7a | 7.7 · 7.5 · 7.0 | **기기 ABI 하나만**(Play가 나눠 보냄) |
| dex(R8 켜짐) | 3.1 | 예 |
| assets 오디오(ogg) | 2.7 | 예 — 이미 압축 포맷 |
| assets 폰트(ttf 9.7MB) | 1.9 | 예 |
| assets 선원 초상·UI·FX PNG | 1.4 | 예 — PNG는 이미 최적(무손실 재압축 0%, 385장) |
- **사용자 다운로드(폰 하나)** ≈ lib 한 ABI 7.5 + dex 3.1 + assets 6 ≈ **17MB**. aab 61.7MB의 절반은 사용자에게 안 가는 메타데이터다.

## 2. 이번에 한 것 / 할 것
| 항목 | 효과 | 상태 |
| --- | --- | --- |
| 네이티브 디버그 심볼 `ndk.debugSymbolLevel = "SYMBOL_TABLE"`(release, build.gradle.kts) | aab −20MB 이상 예상(26MB FULL → 함수 이름표만). Play·Crashlytics 스택의 **함수 이름은 그대로**(줄 번호만 빠짐) | 넣음(review/app-size) — 실제 aab 크기는 다음 A줄 빌드로 확인 |
| 폰트 서브셋 `docs/store/size/subset_fonts.py` — 쓰는 글자 1,121 + KS X 1001 한글 2,350 + 라틴 확장, 힌팅 유지 | Galmuri11 5.2→0.5MB · Bold 2.6→0.4MB · Jua 2.1→2.0MB(Jua는 힌팅이 대부분) — 폰트 9.7→2.9MB, **다운로드 약 −1.0MB** | 스크립트·수치만 — 에셋 교체는 S3(assets 담당), 원본은 tools/art/fonts_src/ 보관 |
| (선택) Jua 힌팅 빼기(`--no-hinting`) | Jua 2.0→1.3MB, 다운로드 추가 −0.3MB | 글자 래스터가 바뀔 수 있어 S3가 골든 확인 뒤 |
| x86_64 ABI 빼기 | aab −7.7MB, 사용자 다운로드 변화 없음 | **하지 않음** — 크롬북·x86 기기가 설치 못 함 |
| PNG 재압축 | 0% | 할 것 없음 |
| 안 쓰는 에셋 | 저장소 assets/ui 2.4MB 중 번들은 0.3MB(pubspec 목록만 들어감) | 번들 안에서 안 쓰는 파일 찾기는 S3(그림 id 참조) |

## 3. 목표 대비
- aab: 61.7MB → 약 38~40MB 예상(−35%, 디버그 심볼) + 폰트 −1.5MB → **목표 −20% 넘음**(A줄 빌드로 확인).
- 사용자 다운로드: 약 17MB → 약 16MB(폰트). 더 줄이려면 libflutter(엔진) 다음으로 큰 libapp(우리 Dart 코드 8MB raw)·오디오가 남는다 —
  오디오는 비트레이트 낮추기(손실 — 사람 귀로 확인 필요), Dart는 `--split-debug-info`·`--obfuscate`(이미 R8, Dart 쪽은 빌드 명령 확인).
- 폰트 서브셋을 넣으면 새 문구가 서브셋 밖 글자를 쓰는지 `subset_fonts.py --check`로 검사(빠지면 종료 1) — check에 넣는 건 S1(tool/).
