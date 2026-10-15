# 효과음·배경음 후보 — CC0 vs 자작(OWN) 비교

- 2026-10-15, S5(platform). 사람이 들어 보고 고른다. 고른 뒤 에셋 등록(`apps/game/assets/audio/`·`LICENSES.json`)은 S1/S3가 한다.
- 기준: 도트/칩튠 해적 톤(battle_ship.gif). 효과음은 대부분 0.1~0.5초, 6개가 한 프레임에 겹쳐도(`fx_map.sfxMaxPerFrame` 6, 같은 id 40ms 간격) 귀가 피곤하지 않아야 한다.
  같은 세트 안에서 톤이 통일돼야 한다.
- 라이선스: CC0 후보는 **페이지에서 직접 본 라이선스 문구**만 인용했다. 확인하지 못한 것은 표에서 뺐다(맨 아래 "제외").
- **주의**: 이 표를 만든 Claude는 소리를 들을 수 없다. 톤 평가는 설계(자작)나 페이지 설명(CC0)에 근거한 것이다. CC0 후보의 길이는 페이지에 없어 대부분 다운로드 뒤 재야 한다.

## 듣는 법 (자작)
1. 브라우저로 열기: **`D:\Projects\pde-platform\docs\store\audio-preview\index.html`** — 전부 한 페이지에서 재생할 수 있다.
2. 파일이 없으면 다시 굽기(약 20초, 같은 입력이면 같은 바이트):
   `python -I -B docs/store/audio-gen/gen_audio.py` → `docs/store/audio-preview/`. wav는 커밋하지 않는다(약 12MB).
3. 먼저 **`mix/battle_coral.wav`**(전투 10초 모의)를 들어 본다. 산호해 배경음 위에 타격·처치·콤보·스킬·궁극기가 겹침 상한 규칙대로 깔린다. 귀가 피곤한지는 이걸로 판단한다.

파일 이름 규칙(게임 `audio_adapter`와 같음):
- `hit`·`hit_crit`는 변형 `_0`·`_1`·`_2` 세 개를 **모두** 쓴다. 게임이 돌아가며 고르고 피치도 ±8% 흔든다.
- 나머지 id는 `_0`~`_2`가 **고를 후보 3개**다. 하나를 골라 `<id>.ogg`로 넣는다.

## 효과음 — id별 비교 (추천 ★)

CC0 칩튠 세트의 1순위는 **512 Sound Effects (8-bit style)**(Juhani Junkala)다. 한 팩으로 대부분 채워 톤이 통일된다.
- 페이지: https://opengameart.org/content/512-sound-effects-8-bit-style
- 라이선스: 페이지에 "CC0" 라벨. 팩 동봉 INFO.txt 원문 "These sound effects have been released under CC0 creative commons license."
- 형식: 44100Hz 16bit mono wav.

| id | 게임에서 | 자작 (OWN) — 미리 듣기 | CC0 후보 A | CC0 후보 B | 추천 |
| --- | --- | --- | --- | --- | --- |
| hit | 일반 타격, 가장 자주 | `sfx/hit_0~2.wav` 0.10초, 피크 0.32. 둔탁한 펄스 낙하 + 짧은 노이즈, 11kHz 위 깎음 | 512팩 `sfx_damage_hit1–10.wav` | 512팩 `sfx_sounds_impact1–15.wav`(더 짧고 둔함) | ★ 자작 — 겹침 규칙에 맞춰 길이·음량을 설계했고 변형 3개가 한 세트. 512팩은 길이를 재 봐야 함(0.2초 넘으면 탈락) |
| hit_crit | 치명타 | `sfx/hit_crit_0~2.wav` 0.16초, 피크 0.5. 딸깍 + 큰 낙하 + 거친 노이즈 + 저음 쿵 | 512팩 `sfx_exp_shortest_hard1–10.wav` | 512팩 `sfx_wpn_cannon1–6.wav`(대포 테마) | ★ 자작 (hit와 같은 합성기라 톤이 이어짐) |
| pop | 처치 | `sfx/pop_0~2.wav` 0.11초. 위로 튀는 블립 + 작은 터짐 | 512팩 `sfx_exp_shortest_soft1–9.wav` | 512팩 `sfx_sounds_Blip1–11.wav`(가벼움) | ★ 자작 |
| combo | 연속 처치 | `sfx/combo_0~2.wav` 0.43초. 빠른 상승 아르페지오 C–E–G–C + 메아리. 0/1/2는 조(C/D/E)만 다름 | 512팩 `sfx_coin_cluster1–9.wav` | Kenney 63 Digital SFX의 power-up 12종 (https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc, "CC0", 크레딧 "not mandatory") | ★ 자작 `combo_0` |
| skill | 선원 스킬 | `sfx/skill_0~2.wav` 0.30초. 올라가는 잽 + 휙 하는 바람 | 512팩 `sfx_wpn_laser1–12.wav` | Kenney 63 Digital SFX phaser/zap | 자작 / 512팩 비슷 — 들어 보고. 레이저 톤이 해적과 안 맞으면 자작 |
| ultimate | 궁극기 (화면 전체) | `sfx/ultimate_0~2.wav` 0.97초. 모으는 상승음 0.22초 → 큰 폭발 | 512팩 `sfx_exp_long1–6.wav` | 512팩 `sfx_sounds_powerup1–18`(앞) + `sfx_exp_cluster`(뒤) 겹치기 | ★ 자작 — 모으기와 폭발이 한 파일. 512팩은 두 파일을 합치는 편집이 필요 |
| boss_horn | 보스 등장 | `sfx/boss_horn_0~2.wav` 1.27초. 해적 뿔나팔 두 번(짧게·길게, 톱니파 근음 + 5도 + 비브라토) + 낮은 우르릉 | 512팩 `sfx_alarm_loop1–8.wav`(루프라 1~2초로 잘라야 함) | freesound "16 bit Klaxon / Alarm Synth Loop" (https://freesound.org/people/Andygun11/sounds/808538/, "Creative Commons 0", 22.2초 → 잘라 씀) | ★ 자작 — 경보음보다 '뿔나팔'이 해적 테마에 맞음 |
| boss_clear | 보스 격파 | `sfx/boss_clear_0~2.wav` 1.16초. 승리 징글(펄스 2 + 삼각 베이스) | "Victory sting" (https://opengameart.org/content/victory-sting, "CC0", TIC-80) | FrogPog Chiptune SFX Pack `level_passed.wav` (https://opengameart.org/content/chiptune-sfx-pack, "CC0", NesVST) | 자작 `boss_clear_0` / Victory sting — 들어 보고 |
| fail | 보스 시간 초과 | `sfx/fail_0~2.wav` 0.86초. 부드럽게 내려가는 3음 + 끝음이 처짐. 벌주는 느낌 없게. 1=단조, 2=짧은 버전 | FrogPog `fail.wav` (같은 팩, "CC0") | "Game over short jingle" (https://opengameart.org/content/game-over-short-jingle, "CC0") | ★ 자작 `fail_0` — '게임 오버' 징글은 너무 무겁다(파밍 전환일 뿐) |
| fanfare | 배 등급 상승 | `sfx/fanfare_0~2.wav` 1.62초. 따-따-따-따안 → 장식 → 따안 + 스네어 롤 | "Victory" (https://opengameart.org/content/victory, "CC0", "2A03 Victory fanfare") | Kenney Music Jingles (https://kenney.nl/assets/music-jingles, "Creative Commons CC0") NES 악기판 (파일명 미확인) | 자작 / Victory(2A03 = 진짜 NES 음원) — 들어 보고 |
| fanfare_small | 부품 마일스톤 | `sfx/fanfare_small_0~2.wav` 0.53초. E–G–C 짧은 징글 | 512팩 `sfx_sounds_fanfare1–3.wav` | "new thing get" (https://opengameart.org/content/new-thing-get, "CC0") | ★ 자작 (fanfare와 같은 동기라 이어 들림) |
| promote | 선원 승급 | `sfx/promote_0~2.wav` 0.79초. 7음 상승 아르페지오 + 높은 반짝임 + 메아리 | FrogPog `level_up.wav` ("CC0") | wobbleboxx "Level up, power up, Coin get" (https://opengameart.org/content/level-up-power-up-coin-get-13-sounds, "CC0", aif일 수 있어 변환 필요) | ★ 자작 |
| (추가) cannon | 대포 발사 — **fx_map에 이벤트 없음** | `sfx/cannon_0~2.wav` 0.14초, 피크 0.3 | 512팩 `sfx_wpn_cannon1–6.wav` | — | 넣으려면 render 레인 이벤트 요청 필요(발사는 타격보다 잦다 → 더 작게) |
| (추가) coin | 골드 획득 — **fx_map에 없음** | `sfx/coin_0~2.wav` 0.26초. sfxr 고전 2음 | 512팩 `sfx_coin_single*.wav` | — | 골드 획득 연출이 생기면 |

### 자작 효과음 설계
- 합성기: `docs/store/audio-gen/chipsynth.py`. 표준 라이브러리만 쓰는 sfxr 방식이다.
- 음원: 펄스(duty 12.5/25/50%), NES풍 16단 계단 삼각파, 샘플 앤 홀드 노이즈.
- 피치·duty 미끄럼, 비브라토, 아르페지오, 1극 필터, 메아리를 쓴다.
- 품질 처리:
  - 펄스를 0 평균으로 만들었다(실제 칩의 AC 결합처럼). 좁은 duty의 DC 치우침이 −0.13까지 나와서 고쳤다.
  - 15Hz DC 차단, 11kHz 위 저역 통과(NES 출력단 느낌, 높은 음의 앨리어싱 거친 소리 감소), 시작 1ms·끝 6ms 페이드.
- 음량을 미리 맞춰 두었다:
  - 자주 겹치는 소리: hit 0.32, cannon 0.3, pop 0.38
  - 중간: hit_crit 0.5, combo 0.5, skill 0.52, fail 0.5
  - 드문 소리: fanfare 0.75, ultimate 0.8, boss 0.7, promote 0.7
- 테스트(`test_gen_audio.py`, 7개): fx_map id 전부 포함, 자주 울리는 소리는 0.2초·피크 0.5 이하, DC·클리핑·양끝 무음, 변형이 서로 다름, 결정론, 배경음 마디 길이·루프 이음매·음량.

## 배경음 — 해역별 비교

| bgm id | 해역(스테이지) | 자작 (OWN) — `bgm/<id>.wav` | CC0 후보 A | CC0 후보 B | 추천 |
| --- | --- | --- | --- | --- | --- |
| bgm_coral | 산호해 1–50, 밝은 모험 | 29.1초 루프, 132 BPM, C장조 C–G–Am–F, 펄스 리드 + 16분 아르페지오 + 삼각 베이스 + 노이즈 드럼. 2회차는 리드 음색 바뀜 | Juhani Junkala "4 Chiptunes (Adventure)" Stage 1 (https://opengameart.org/content/4-chiptunes-adventure, "CC0", "Seamlessly looping.") | Junkala "JRPG Pack #1 [Exploration]" `Tropical Island.ogg` (https://opengameart.org/content/jrpg-pack-1-exploration, "CC0", 루프 미확인) | ★ CC0 A — 진짜 칩튠이고 루프가 명시돼 있음. 자작은 대안 |
| bgm_storm | 폭풍해 51–100, 긴장·질주 | 25.6초, 150 BPM, D단조, 옥타브 펄스 베이스, 16분 하이햇 | Junkala "5 Chiptunes (Action)" level1~3 (https://opengameart.org/content/5-chiptunes-action, "CC0", "all seamlessly looping!") | Sudocolon "Chip Bit Danger" (https://opengameart.org/content/chip-bit-danger, "CC0", 댓글에 "반복감이 강하다" → 피로 우려) | ★ CC0 A (5곡 중 하나 고름) |
| bgm_glacier | 빙하해 101–150, 차갑고 반짝 | 41.7초, 92 BPM, E단조 Em7–Cmaj7–G–D, 삼각파 리드 + 메아리 아르페지오, 드럼 최소 | Jonathan So "Fields of Ice" (https://opengameart.org/content/fields-of-ice, "CC0", Famitracker 칩튠. "the audio loops once" → 루프 지점 확인 필요, 태그가 action이라 차분하지 않을 수 있음) | itch.io hyperpixel "33 Free Chiptune Loops" ("Creative Commons Zero v1.0 Universal", "All tracks loop seamlessly") 중 조용한 곡 | 자작 / Fields of Ice — 들어 보고 (자작이 '차분'에 더 맞게 설계됨) |
| bgm_volcano | 화산해 151–200, 무겁고 뜨거움 | 27.8초, 138 BPM, C프리지안 Cm–Db(♭II), 파워코드 8분 + 16분 베이스 + 킥 | pmiller "Chiptune Battle Music" (https://opengameart.org/content/chiptune-battle-music, "CC0", "Free to use without attribution.", 약 7.5초 지점부터 루프 구간) | hyperpixel 33 Loops (150BPM C단조 계열 다수) | CC0 A / 자작 — 들어 보고. 루프 구간이 짧으면 피로 |
| bgm_abyss | 심연 201–250, 어둡고 깊음 | 48.0초, 80 BPM, A단조 Am–F–Dm–E, 12.5% 펄스 리드 + 느린 비브라토 + 메아리, 킥 1박만 | congusbongus "Cathedral in the forest (ambient loop)" (https://opengameart.org/content/cathedral-in-the-forest-ambient-loop, "CC0", "Seamless ambient loop, for space or dark games", 칩튠 아님) | Junkala "JRPG Pack #3 [Evil]" `Evil2 - Catacombs.ogg` (https://opengameart.org/content/jrpg-pack-3-evil, "CC0", 루프 미확인) | 자작 — 칩튠 톤 통일. A는 칩튠이 아니라 다른 해역과 결이 다름 |
| bgm_phantom | 유령해 251–300, 유령 해적 | 24.8초, 116 BPM, **3/4 왈츠**, E단조 Em–Am–B7, 깊은 비브라토 리드 + 메아리 | Zane Little "Haunting Chiptune Loop [Void Estate]" (https://opengameart.org/content/haunting-chiptune-loop-void-estate, "CC0", "A spooky chiptune loop") | Wolfgang_ "8-bit Haunted House Theme" (https://opengameart.org/content/8-bit-haunted-house-theme, "CC0", 루프 미확인) | ★ CC0 A — NES풍 유령 칩튠 루프 |

- 자작 배경음 설계: 4채널(펄스 리드, 펄스 반주, 삼각 베이스, 노이즈 드럼), 22050Hz. 8마디를 2번 돌고(2회차는 리드 음색 변경, 마지막 마디는 스네어 채우기), 끝을 넘친 꼬리를 앞에 더해 이음매 없이 이어진다. 곡마다 RMS 0.11로 체감 크기를 맞췄다.
- 자작의 약점(솔직히): 8마디 × 2 = 25~48초로 짧다. 방치형으로 오래 틀면 반복이 귀에 띌 수 있다. 전문 작곡가(Junkala 등)의 CC0 곡이 음악적으로는 더 풍부할 가능성이 크다. 그래서 루프가 명시된 CC0 곡을 먼저 추천한다.
- CC0 선택 크레딧(의무 아님): Jonathan So, Cleyton Kauffman, Kenney 등은 크레딧을 원한다. 넣는다면 크레딧 화면에 넣는다.

## 고른 뒤 할 일 (S1/S3)
1. **ogg 변환**: 게임은 `.ogg`만 찾는다(`audio_adapter`: `sfx/<id>.ogg`·`sfx/<id>_<n>.ogg`·`bgm/<id>.ogg`). 이 PC에는 ffmpeg·oggenc·sox가 없다.
   → 사람이 ffmpeg를 설치(`winget install Gyan.FFmpeg`)한 뒤 `ffmpeg -i x.wav -c:a libvorbis -q:a 4 x.ogg`. 또는 Audacity로 내보내기.
2. 자작을 고르면 `apps/game/assets/audio/` 아래 위 이름으로 넣고 `LICENSES.json`에 `OWN`(생성 스크립트 `docs/store/audio-gen/gen_audio.py`). 스크립트는 art 레인 `tools/art/`로 옮기는 게 맞다.
3. CC0를 고르면 `LICENSES.json`에 출처 URL과 라이선스 문구, 다운로드 날짜를 적는다. 길이를 재서 hit 계열이 0.2초를 넘으면 자르거나 탈락시킨다.
4. 섞어 써도 된다. 예: 효과음은 자작(톤 통일, 겹침 설계), 배경음은 CC0(곡 품질).

## 제외 (라이선스 미확인 또는 CC0 아님)
- 라이선스가 CC0이 아님: Dark Ambience Loop(CC-BY 3.0/GPL), Fire Maze(CC-BY 4.0), Cauldron Boiling Hell(CC-BY 계열), Relaxing chiptune Music(CC-BY 4.0), Their Spears Fell Like Rain(CC-BY 4.0), bart "Level up sound effects"·BitBleep·dklon(CC-BY).
- Memoraphile "Spooky Dungeon": CC-BY 4.0·OGA-BY 3.0·CC0가 함께 걸려 있다. 라이선스가 여러 개라 뺐다. 필요하면 CC0로 확인 후 phantom 보조 후보.
- Cleyton Kauffman "Snow Theme"("CC0", 0:24, 루프 됨): 칩튠이 아니고(종·차임 앰비언트) 너무 짧아 뺐다. 빙하해를 차분하게 가고 싶으면 다시 검토.
- Kenney Impact Sounds("Creative Commons CC0"): 라이선스는 맞지만 실제 녹음(foley) 소리라 도트 톤과 어긋나서 뺐다.
- freesound는 효과음 1건만 조사했다. 배경음은 조사하지 못했다.
