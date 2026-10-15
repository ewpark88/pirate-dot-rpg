# platform → ui: 스토어 스크린샷에서 드러난 화면 문제 2건 (S1 중계 → S4)

- 요청 레인 / 날짜: platform(S5) / 2026-10-15 · 도구 `apps/game/test/store/store_shots_test.dart`(STORE_SHOTS=ko|en)
- 바꿀 경로: ui 레인 소유(`apps/game/lib/ui/summon/summon_result.dart`). 계약 변경 없음.

## 왜 필요한가
1. **360dp 폭에서 소환 결과 칸 overflow**: 논리 360×640(가장 흔한 안드로이드 폭)으로 10연 결과를 그리면
   `summon_result.dart:171` Column이 아래로 0.7px 넘친다(RenderFlex overflowed, 디버그 빌드에서 노랑·검정 줄무늬).
   스크린샷은 411dp로 피했지만 실제 360dp 기기에서는 생긴다.
2. **소환 결과 카드 이름이 거의 다 잘린다**(411dp에서도): 영어 "Starr y th…", "Uni the …", "Crab Bro…", 한국어 "폭풍 가오…", "불가사리 …".
   스토어 4번 스크린샷(“선원 40명 소환”)의 주인공 화면이라 눈에 띈다. 별 줄도 이름과 겹쳐 좁다.

## 제안
- 카드 이름은 짧은 이름(별명 없이 종 이름만, 예: "Manta"·"가오리") 키를 따로 쓰거나, 2줄 + 글자 크기 한 단계 작게.
- 칸 높이를 고정값 대신 내용에 맞추거나(`IntrinsicHeight` 대신 여유 2px), 별 줄을 이름 위로.
- 확인: `STORE_SHOTS=en flutter test test/store/store_shots_test.dart` → `build/store/screens/en/04_summon.png`, 그리고 360dp 위젯 테스트 1개.

## 그동안
스크린샷은 411dp(1080×1920 ÷ 2.625)로 굽는다. 이름 잘림은 그대로 찍힌다.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
