# 짧은 시나리오 — 오프닝·보스 대사 (S2, 2026-10-17)

사용자 요청: '게임 시작 때 세계관을 잠깐(스킵 가능), 보스 나오기 전에 보스와 주인공들의 대화(스킵 버튼, 클릭 안 해도 자동으로 넘어가며 전투는 계속 — 방치형)'. 목표는 핵앤슬래시 쾌감이라 **대사가 전투를 멈추지 않는다**.

## 흐름
- **오프닝**: 첫 실행 한 번, 5컷(한 컷 2줄 이하). 컷마다 `openingCutSec` 3초 자동 넘김, 누르면 다음, '건너뛰기'로 끝. 그동안 뒤에서 첫 무리 전투가 이미 돈다(튜토리얼 1단계와 겹침 — 끝나면 TutorialAck(1)).
- **보스 등장 대사**: 보스가 나타나는 순간 말풍선 2줄(보스 → 선원). 한 줄 `lineSec` 2.5초 자동, 누르면 다음, 건너뛰기 버튼. **전투는 계속**(보스도 이미 싸운다).
- **처치 한 줄**(선택): 보스를 잡으면 `outro` 중 하나 1줄.
- 같은 보스를 다시 만나면(재도전·환생 뒤) 보스 줄 1개만 또는 끔 — 설정 '보스 대사' 토글 제안(S4).

## 데이터 (`packages/game_data/tables/story.json`, 문구 `battle` ARB)
- `speakers`: narrator·boss·octo·bones. `opening[]`: art(그림 id) + lines. `bosses{보스 id: intro[]}`: 고유 대사. `traitLines{특성 또는 default: [[줄…]…]}`: 공용 대사 여러 벌. `outro[]`. 줄마다 `{who, nameKey}` — check가 ARB 키를 대조한다.
- 고르는 규칙(`StoryTable.bossIntro(boss, pick)`): 고유가 있으면 그것 → 없으면 첫 특성의 공용 → 특성이 없으면 default. `pick`은 스테이지 번호 등(벌을 돌려 쓴다). 42종 보스 모두 대사를 받는다(시험 story_test).
- 보스 특성 힌트를 대사에 녹였다(회피 '어딜 쏘는 거야?' → '넓게 터뜨리면 못 피하지!' 등) — 화면의 특성 칩과 같은 내용을 말로.

## 할 일 나눔
- 엔진(S5, 필요하면): 보스 등장 순간 이벤트 `BossIntro(bossId, stage)` — 화면이 `bossIntro(def, stage)`로 줄을 고른다(엔진은 대사를 몰라도 됨).
- 화면(S4): 오프닝 컷 화면(건너뛰기), 전투 위 말풍선(얼굴 + 줄, 자동 넘김 링, 건너뛰기), 처치 한 줄. 오프닝 그림 5장(`opening_1~5`)은 S3 HD 도구로.
- 문구 길이: ko 한 줄 20자 안팎, en 45자 안팎 — 360dp 말풍선 두 줄 안.

## 대본
### 오프닝
1. 해설: 반짝반짝 보물이 잠든 일곱 바다. / Seven seas, sparkling with treasure. · 해설: 그런데 바다 괴물들이 몽땅 차지했대요! / But sea monsters grabbed it all!
2. 옥토: 나는 옥토, 꼬마 해적선의 선장! / I'm Octo, captain of a tiny pirate ship! · 옥토: 먹물 폭탄이라면 자신 있지! / Nobody throws ink bombs like me!
3. 해설: 배는 알아서 싸워요. / The ship fights all on its own. · 해설: 우리는 배를 키우고 동료를 모으면 돼! / We just upgrade it and gather a crew!
4. 해설: 바다마다 버티는 큰 보스들… / A big boss guards every sea... · 해설: 하나씩 무찌르고 보물을 되찾자! / Beat them one by one and win the treasure back!
5. 옥토: 출항이다! 우수수 쓸어 버리자! / Set sail! Let's sweep them all away!

### 고유 대사 (해역 보스 6 · 대보스 6)
| 보스 | 보스 대사 | 선원 대사 |
| --- | --- | --- |
| 대왕 소라게 (`giant_hermit`) | 내 껍데기는 정면으론 못 뚫어! / You'll never crack my shell head-on! | 옥토: 그럼 위에서 폭탄을 떨어뜨리지! / Then I'll drop bombs from above! |
| 번개 가오리 (`thunder_ray`) | 찌릿! 내 번개 맛 좀 볼래? / Zzzap! Want a taste of my lightning? | 옥토: 번개보다 우리 대포가 빠를걸! / Our cannons are faster than lightning! |
| 빙산 바다코끼리 (`iceberg_walrus`) | 얼음처럼 단단한 이 엄니를 봐라! / Behold my tusks, hard as ice! | 본즈: 얼음은 깨라고 있는 거지. / Ice is made for breaking. |
| 용암 고래 (`lava_whale`) | 부글부글… 바다를 끓여 주마! / Bubble bubble... I'll boil the sea! | 옥토: 앗 뜨거! 빨리 끝내자! / Yikes, hot! Let's finish this fast! |
| 크라켄 (`kraken`) | 여덟 다리로 배째 삼켜 주지! / I'll swallow your ship with eight arms! | 옥토: 다리라면 나도 여덟 개야! / Hey, I've got eight arms too! |
| 유령 함대 제독 (`ghost_admiral`) | 내 유령 함대는 끝없이 몰려온다… / My ghost fleet never stops coming... | 본즈: 그럼 끝없이 쓸어 주지. / Then we'll never stop sweeping. |
| 바다 악어 (`sea_croc`) | 약한 공격은 간지럽다! 화나면 더 무섭고! / Weak hits just tickle! And I get scarier when I'm mad! | 옥토: 작게 말고 한 방에 크게! / Skip the small shots—hit it big! |
| 괴물 고래 (`monster_whale`) | 때려도 금방 낫지! 꼬마들아, 나와라! / I heal right back! Come out, little ones! | 옥토: 호위부터 쓸고, 나을 틈을 주지 마! / Clear the escorts—don't give it time to heal! |
| 거대 얼음 아메바 (`ice_slime`) | 말랑말랑… 깎아도 다시 차오르지. / Squishy... whatever you shave grows back. | 본즈: 그럼 한 번에 크게 깎아야겠군. / Then we'll carve big chunks at once. |
| 레비아탄 (`leviathan`) | 내 비늘은 공격을 되돌려 보낸다! / My scales send your attacks right back! | 옥토: 막이 걷힐 때를 노리자! / Wait for the shield to drop, then strike! |
| 크라켄 문어 (`kraken_titan`) | 거인 크라켄 납신다! 호위대, 막아라! / The Titan Kraken is here! Guards, hold them! | 옥토: 호위 먼저, 그다음 큰 한 방! / Escorts first, then one big blow! |
| 포세이돈 (`poseidon`) | 바다의 왕 앞에 무릎 꿇어라! / Kneel before the King of the Sea! | 옥토: 왕관 말고 보물이나 돌려줘! / Forget the crown—give back the treasure! |

### 공용 대사 (특성별 · default)
| 특성 | 보스 대사 | 선원 대사 |
| --- | --- | --- |
| evade | 어딜 쏘는 거야? 난 여기 있지! / Where are you aiming? I'm over here! | 옥토: 넓게 터뜨리면 못 피하지! / It can't dodge a big blast! |
| evade | 포탄 따위 다 피해 주마! / I'll dodge every cannonball! | 본즈: 그럼 피할 곳을 없애지. / Then we leave nowhere to dodge. |
| armor | 약한 공격은 안 통해! / Weak attacks won't work on me! | 옥토: 한 방에 세게 가자! / One hard hit, then! |
| armor | 단단함이라면 바다 최고! / Toughest shell in the sea! | 본즈: 큰 포탄으로 깨 주지. / A big cannonball will crack it. |
| regen | 다쳐도 금방 나아! / I heal in no time! | 옥토: 나을 틈을 주지 말자! / Don't give it time to heal! |
| regen | 후후, 회복 중… / Heh heh, healing up... | 본즈: 몰아쳐서 끝내자. / Pile on and finish it. |
| reflect | 내 막에 맞으면 되돌아간다! / Hit my shield and it bounces back! | 옥토: 막이 걷힐 때를 노려! / Strike when the shield drops! |
| reflect | 반사막, 펼쳐라! / Mirror shield, up! | 본즈: 잠깐 쉬었다 치자. / Hold fire a moment, then hit. |
| enrage | 체력이 줄수록 더 세진다! / The lower my health, the stronger I get! | 옥토: 화내기 전에 끝내자! / Finish it before it gets mad! |
| enrage | 화났다! 진짜 화났다! / I'm mad! Really mad! | 본즈: 배를 단단히 해 둬. / Brace the hull. |
| escort | 부하들아, 나와라! / Minions, come out! | 옥토: 호위부터 쓸어 버리자! / Sweep the escorts first! |
| escort | 혼자 싸울 줄 알았냐! / Thought I'd fight alone? | 본즈: 몰려오면 한꺼번에 쓸지. / More of them, bigger sweep. |
| dash | 들이받아 주마! / I'll ram you! | 옥토: 배 지킴이들, 막아! / Guards, block it! |
| dash | 빠르게, 더 빠르게! / Faster, even faster! | 본즈: 멈출 때가 기회다. / When it stops, we strike. |
| default | 여기는 못 지나간다! / You shall not pass! | 옥토: 그럼 뚫고 가지! / Then we'll break through! |
| default | 보물은 내 거야! / The treasure is mine! | 옥토: 돌려받으러 왔어! / We came to take it back! |
| default | 해적 주제에 덤비냐! / Pirates? Picking a fight with me? | 본즈: 해적이니까 덤비지. / Pirates pick fights. That's the job. |

### 처치 한 줄
- 옥토: 보물 하나 되찾았다! / One treasure back!
- 옥토: 우수수~ 다음 바다로! / Swept away! On to the next sea!
- 본즈: 역시 우리 배가 최고군. / Our ship really is the best.
