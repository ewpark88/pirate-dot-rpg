# 계획: 렌더 — 효과음·배경음 연결

- 스펙: `docs/specs/render-audio.md` (승인됨 2026-10-14, S1 — 계약 E 수용) · 계약 요청: `docs/contracts/requests/render-audio.md` · 레인: render(S3)

## 단계
- [x] 0. 스펙 승인 · 계약 E(AudioPort) 결정
- [x] 1. fx_map `sfxMinGapMs`·`sfxMaxPerFrame` + 모델
- [x] 2. 테스트 먼저: 수용 기준 1~5 (SilentAudio)
- [x] 3. `scene/sound_director.dart`(sfx id·변형·피치·상한), BGM(해역 전환)
- [x] 4. `BattleGame(audio:)`, `audioLog`
- [ ] 5. (art) CC0 효과음·BGM 고르기 → assets/audio + LICENSES — M4 사용자 확인 목록(사람 몫) 대기
- [ ] 5b. flame_audio 어댑터 — platform 경로(adapters/)라 S1/플랫폼
- [x] 6. `tool\check.bat --full` → 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
