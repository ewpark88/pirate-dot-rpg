# 디자인 개편 화면 목록표 (쿵푸할매 스타일, S1 지시 2026-10-17)

> 계획: `docs/plans/active/design-kungfu-style.md`. 이 표는 **모든 창·탭·HUD 요소**를 빠짐없이 적은 체크리스트다 — S4(ui)·S5(platform)·S3(render) 공유.
> 키트(main 머지됨): `assets/ui/kit/{button_gold, button_primary, button_secondary, panel, tab_active, tab_idle, chip, badge_frame}.png` @1x·2x·3x —
> `Image.asset('assets/ui/kit/<이름>.png', centerSlice: …)`, 1x centerSlice: 버튼 (24,24,244,72) · panel (20,20,288,172) · tab (12,12,142,40) · chip (20,10,110,28) · badge 늘리지 않음.
> 열: **키트** = 바꿀 요소(P 패널 · B 버튼 · T 아래/위 탭 · R 리본 제목 · C 칩/배지 · I HD 아이콘 · O 흰 글씨+검은 테) · **골든** = `apps/game/test/ui/<파일>` 골든 수(재생성은 S1 절차) · **담당** 제안.
> 체크: ☐ 안 함 · ◐ 일부 · ☑ 끝(골든 재생성까지). 화면 4종(360·384·411·태블릿) 확인은 ☑ 조건.

## 0. 공용 부품 (먼저 — 아래 화면 대부분이 이것을 쓴다)
| 부품 | 파일(apps/game/lib/ui/) | 키트 | 골든 | 담당 | 체크 |
| --- | --- | --- | --- | --- | --- |
| 스킨 테마·색 토큰 | skin/skin.dart | 남색·보라 판, 노랑·초록 버튼 색 | skin_r1·r2_mock | S4 | ☐ |
| 버튼 | skin/skin_button.dart, pixel/pixel_button.dart, pixel/pixel_icon_button.dart | B(gold·primary·secondary 9-slice) | 거의 전부 | S4 | ☐ |
| 판·창 | pixel/pixel_frame.dart, pixel/pixel_dialog.dart, skin/pb_card.dart | P + R(리본 제목) | 거의 전부 | S4 | ☐ |
| 탭 막대 | pixel/pixel_tab_bar.dart | T(tab_active·tab_idle) | tabs_golden | S4 | ☐ |
| 막대·고리·토글 | pixel/pixel_bar.dart, pixel_ring.dart, pixel_toggle.dart | 굵은 테 + 광택 | hp·stage 관련 | S4 | ☐ |
| 아이콘 | skin/skin_icon.dart, pixel/pixel_icon_button.dart, pixel/pixel_sprite.dart | I(PB ui/icons SVG → HD) | 거의 전부 | S3 그림 · S4 연결 | ☐ |
| 글자 | text/number_text.dart, big_num_text.dart, crew_name.dart | O(흰 글씨 + 검은 테) | 거의 전부 | S4 | ☐ |
| 토스트·말풍선·반짝이 | skin/skin_toast.dart, hud/hud_bubble.dart, skin/reward_sparkle.dart | P 작은 판, 반짝이 | fun_strips | S4·S3 | ☐ |
| 등급색 칸 | widgets/rarity_color.dart, widgets/crew_portrait.dart | 등급색 네모 칸 + 굵은 테 | crew_* · mythic_frame | S4 | ☐ |

## 1. 홈·아래 탭 (home_screen.dart, tabs/)
| 화면 | 파일 | 키트 | 골든 | 담당 | 체크 |
| --- | --- | --- | --- | --- | --- |
| 아래 탭 4칸(배·선원·소환·항해) | home_screen.dart, tabs/* | T(선택 칸만 노랑) · I | tabs_golden · core_loop · m3 | S4 | ☐ |
| 배 탭(부위 강화 칸·배수 고르기) | tabs/ship_tab.dart, upgrade_multiplier.dart | P · B · I(부위 아이콘) · O | m3 · bulk_upgrade | S4 | ☐ |
| 선원 탭(카드 격자·필터) | tabs/crew_tab.dart, crew_card.dart, crew/crew_filter_bar.dart | C(필터 칩) · 등급색 칸 | crew_filter(3) | S4 | ☐ |
| 소환 탭(1·10연 버튼·천장) | tabs/summon_tab.dart, summon/summon_buttons.dart | B(gold) · P | summon_tab | S4 | ☐ |
| 항해 탭(목표·현상금·도감·환생 입구) | tabs/voyage_tab.dart, meta/goal_bar.dart | P · R · B | m3 | S4 | ☐ |
| 도크(빠른 강화·모두 강화·요청) | dock/home_dock.dart, dock_panels.dart, quick_upgrade.dart, upgrade_all.dart, dock_request.dart | P · B | bulk_upgrade | S4 | ☐ |

## 2. 전투 HUD (hud/)
| 요소 | 파일 | 키트 | 골든 | 담당 | 체크 |
| --- | --- | --- | --- | --- | --- |
| 위 막대(골드·젬·조각·설정) | hud/top_bar.dart | C(재화 칩) · I(coin·pearl·gear) · O | hud_stack · devices | S4 | ☐ |
| 스테이지 게이지·파 진행 | hud/stage_gauge.dart | 굵은 테 막대 | stage_gauge | S4 | ☐ |
| 배·적 HP 막대 | hud/hp_bars.dart | 알약 막대 굵은 테 | hud_stack | S4·S3 | ☐ |
| 전투 오버레이·위 띠 | hud/battle_overlay.dart, battle_top_strip.dart | P(얇은) · O | hud_stack | S4 | ☐ |
| 전투 버튼(보스 도전·광고·빠른 항해) | hud/battle_hud_buttons.dart, boss_challenge_button.dart, sail_start.dart | B | hud_buttons · sail_start | S4 | ☐ |
| 보스 등장·컷인·이름 | hud/boss_intro.dart, boss_cutin_name.dart | R(이름 리본) | boss_intro | S4·S3 | ☐ |
| 보스 브레이크·비교·약점·피해·실패 안내 | hud/boss_break.dart, boss_compare.dart, boss_weakness.dart, boss_damage.dart, boss_fail_notice.dart | C · 굵은 테 막대 · O | boss_break(4) · boss_compare · boss_damage · boss_fail | S4 | ☐ |
| 피버 칸·연출 | hud/fever_slot.dart, fever_drama.dart | 발광 · O | — | S4·S3 | ☐ |
| 상자·금화 도착·화물칸 | hud/chest_edge.dart, chest_layer.dart, coin_arrival.dart, cargo.dart | C(알약) · I | chest · cargo(2) | S4 | ☐ |
| 즐거움 띠(도전·이벤트)·병 고르기 | hud/fun_strips.dart, bottle_choices.dart | P 작은 판 · B | fun_strips | S4 | ☐ |
| 빠른 항해 | hud/fast_sail.dart | P · R · B | fast_sail(2) | S4 | ☐ |
| 배지(파워·순풍)·토스트·저장 실패 | hud/power_badge.dart, tailwind_badge.dart, fleet_rejected_toast.dart, save_failure_banner.dart | C · badge_frame | — | S4 | ☐ |
| 승리 정리 | (battle_clear) | P · R | battle_clear | S4 | ☐ |

## 3. 창·시트
| 창 | 파일 | 키트 | 골든 | 담당 | 체크 |
| --- | --- | --- | --- | --- | --- |
| 선원 상세(능력·전설·특징·성장 이유) | crew/crew_detail.dart, crew_identity*.dart, crew_trait_text.dart, crew_growth_reasons.dart, crew_preview.dart | P · R · B · 등급색 칸 | crew_detail(2) · crew_identity | S4 | ☐ |
| 편성 시트·교체 비교 | crew/fleet_sheet.dart, swap_compare.dart, crew_pill.dart | P · B · C | swap_compare(2) | S4 | ☐ |
| 새 선원 | crew/new_mate.dart | 빛기둥 · R | new_mate | S4·S3 | ☐ |
| 소환 연출·결과 | summon/summon_cutin.dart, summon_pillar.dart, summon_fx.dart, summon_result.dart, summon_card.dart, summon_gate.dart | 빛기둥·반짝이 · 등급색 칸 · B | summon_frames | S3·S4 | ☐ |
| 현상금(시트·카드·전투) | bounty/bounty_sheet.dart, bounty_card.dart, bounty_battle.dart | P · R · B · C | bounty(2) | S4 | ☐ |
| 바다 괴물 도감 | dex/monster_dex.dart | P · 칸 격자 · I | monster_dex | S4 | ☐ |
| 환생(준비·이유·상자·상점·지도·칭호·스킨) | rebirth/rebirth_ready.dart, rebirth_why.dart, rebirth_chest.dart, chest_paint.dart, rebirth_shop*.dart, treasure_route.dart, title_sheet.dart, ship_skin.dart, meta/rebirth.dart | P · R · B · 상자 빛기둥 | rebirth_ready(2) · rebirth_v2(4) | S4·S3 | ☐ |
| 일일(퀘스트·출석) | meta/daily_sheet.dart | P · R · B · 칸 | m3 | S4 | ☐ |
| 오프라인 보상 | offline/offline_reward.dart | P · R · B(gold) | m3 | S4 | ☐ |
| 광고 버튼 | ads/ad_buttons.dart | B · I(ad) | — | S4 | ☐ |
| 설정 | settings/settings_screen.dart, settings_rows.dart | P(묶음 판) · T 토글 | m3 | S4 | ☐ |
| 배 외형 미리보기 | ship/ship_look.dart | P | — | S4·S3 | ☐ |
| 절전 화면 | idle/idle_gate.dart | 어두운 판 | idle | S4 | ☐ |

## 4. 안내·튜토리얼
| 요소 | 파일 | 키트 | 골든 | 담당 | 체크 |
| --- | --- | --- | --- | --- | --- |
| 안내 카드·말풍선·표시·자리 | guide/guide_cards.dart, guide_talk.dart, guide_marks.dart, guide_spots.dart, guide_layer.dart | P 말풍선 · O · 강조 테 | guide(3) · guide_v3_storyboard | S4 | ☐ |
| 튜토리얼 | tutorial/tutorial.dart | P · B | — | S4 | ☐ |

## 5. 렌더(전장) — S3
| 요소 | 위치 | 할 것 | 체크 |
| --- | --- | --- | --- |
| 바다 배경·소품 | render/top/top_sea_painter.dart | 색감·외곽선 소품 | ☐ |
| 연출(발광·빛기둥·반짝이·보상 쏟아짐) | render/top/*, summon/summon_pillar.dart | 쿵푸할매식 발광 | ☐ |
| 몬스터·보스·배 HD(시범 3+1 → 사용자 승인) | tools/art/gen_topdown_*.py | 계획 ④ 시범 먼저 | ☐ |

## 6. 운영자·기타(개편 우선순위 낮음)
| 요소 | 파일 | 비고 |
| --- | --- | --- |
| 운영자 패널 | lib/operator/ | 배포 빌드에 없음 — 개편 마지막(골든 operator_panel) |
| 스토어 스크린샷 | docs/store, tool 스크립트 | 개편 끝난 뒤 다시 굽기(S5) |

## 순서 제안
1. 0번 공용 부품(버튼·판·탭·글자 테) → 대부분 화면이 한 번에 바뀐다(골든 한 번에 재생성).
2. 1번 홈·아래 탭과 2번 HUD 위 막대 — 첫 화면 체감.
3. 3번 창들(선원 상세·소환 결과·환생) — 리본 제목·빛기둥.
4. 4번 안내, 6번은 마지막.
