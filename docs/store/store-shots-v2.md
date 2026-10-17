# 스토어 스크린샷 2차 굽기 계획 (8장) — 문서만, 굽기는 A줄이 빌 때

- 2026-10-18 · S5 · 요청: S1(오늘 들어온 기능: 대군 습격·필살기·HD 보스 59종·탑·상점·패스·업적·도감·편성).
- 도구: 1차와 같다 — `apps/game/test/store/store_shots_test.dart` + `store_shot_kit.dart`(실제 엔진을 샘플 상태에서 돌려 이벤트를 기다렸다 찍음,
  흔들림·번쩍임 끔). 굽기: `cd apps/game` → `STORE_SHOTS=ko flutter test test/store/store_shots_test.dart`(영어 `en`) → `build/store/screens/<ko|en>/`.
  Play 규격: 세로 9:16 1080×1920, 2~8장. 운영자 패널·테스트 광고가 보이면 안 된다.
- 1차(01_multikill … 08_rebirth)는 지금 등록정보에 쓰는 것. 2차가 구워지면 같은 이름 자리로 바꾼다(`listing.*.md` 캡션도 함께).

| 순서 | 파일 | 장면 | 상태·찍는 순간(엔진 이벤트) | 캡션 ko / en |
| --- | --- | --- | --- | --- |
| 1 | 01_horde | 대군 습격 — 바다를 덮은 무리 + HORDE 띠 | 중반 샘플(stage37), `HordeIncoming` 뒤 무리가 화면에 가장 많을 때(crowded) | 대군이 몰려온다! / Here comes the horde! |
| 2 | 02_ultimate | 선장 필살기 컷인·화면 가르기 | 신화 샘플 보스전, `UltimateCast` 뒤 4~8틱(컷인·베기 연출이 화면에 있을 때) | 선장 필살기, 한 방에 / Captain's special move |
| 3 | 03_boss_entry | HD 대보스 등장(해역 대보스, 화면 가득) | 해역 대보스 스테이지(wallEvery 배수)에서 `BossSpawned` 뒤 보스가 standoff에 선 첫 틱 — 체력바·이름 띠 | HD 보스 59종 / 59 HD bosses |
| 4 | 04_tower | 심연의 탑 층 진행(층 띠·무리·남은 시간) | 신화 샘플 + 환생 1, `StartTower` → 3층 2파 무리가 화면 안에 들어온 순간(e1c25d2f 뒤라 화면 밖에서 몰려옴) | 끝없이 깊어지는 심연의 탑 / The ever-deeper Abyss Tower |
| 5 | 05_shop | 상점 시트(젬 팩·광고 제거·2배속·스킨) | `shop_sheet.dart` 위젯 — 가격은 `SimBillingSdk` 흉내 가격(₩ 표시)으로 채움, 첫 구매 2배 표시 | 필요한 것만 골라서 / Only what you want |
| 6 | 06_pass | 항해 패스 시트(무료·유료 줄, 단계 보상) | `pass_sheet.dart` — 패스 xp를 단계 7 근처로 채운 상태(받은 칸·받을 칸·잠긴 칸이 함께 보이게) | 플레이할수록 오르는 항해 패스 / A Voyage Pass that grows as you play |
| 7 | 07_codex | 선원 도감·수집 보상(+ 업적 시트 알약) | 도감 20명 상태 — 수집 보상 칸 하나가 '받기' 상태, 업적 빨간 점 | 선원 40명, 업적 15종 / 40 crew, 15 achievements |
| 8 | 08_fleet | 편성 화면 — 계열이 다른 6명 + 공격 미리보기 | 신화 샘플, 편성 탭 + 선원 상세의 공격 미리보기(CrewPreview, 배 고정 OpSetShipStill) | 보고 고르는 내 선원 / See it, then pick your crew |

## 메모
- 1~4는 전투 장면이라 렌더 골든과 같은 HD 굽기를 쓴다(기기 해상도 굽기 — 시험에서 devicePixelRatio 3). 피버 장면이 없어졌으니 1번이 '쓸어버리는 맛'을 맡는다.
- 5·6은 결제 문구가 나오므로 가격은 흉내 값이라도 원화/달러 형식이 맞아야 한다(Play 정책: 실제 가격과 다르면 안 됨 → 캡처 전에 Play 콘솔 가격과 같은 값으로 흉내 가격을 맞추거나, 가격 칸을 가린 연출로).
- 영어판은 같은 장면 + en 캡션. 그래픽 이미지(1024×500)는 `feature_graphic.py` 그대로.
- 시험 파일 변경(S5 몫 test/store/)은 굽기 차례에: 장면 8개 함수 + 캡션 표. 기존 1차 장면 함수는 남겨 두고 `STORE_SHOTS_SET=v2`로 고른다.
