# 스펙: 렌더 — 효과음·배경음 연결 (M4 사운드 자리)

- 상태: 초안 — 승인 대기 · 레인: render(S3, 호출) + platform(어댑터) + art(에셋, S3) · 설계서 절: 4.4 타격감(소리), 10장 효과음·BGM(CC0)
- 계약 요청: `docs/contracts/requests/render-audio.md` (AudioPort)

## 목적
- 시원한가: 타격·폭발·처치·보스에 소리가 붙는다. 같은 타격음이 반복되지 않게 변형 3종 + 피치 흔들기.
- 피로가 없는가: 같은 소리는 짧은 간격에 겹쳐 울리지 않고(상한), 설정에서 효과음·배경음을 따로 끈다.
- 공정한가: 소리는 연출일 뿐 — 기록·엔진 결과를 바꾸지 않는다. 피치 흔들기도 결정론(틱·대상 id 기반)이라 같은 기록이면 같은 소리 순서.

## 규칙
1. **효과음**: `EventDirector`가 이벤트를 연출할 때 `fx_map.json events[].sfx`를 `AudioPort.playSfx`로 부른다
   (damage→hit, 치명 damage→hit_crit, kill→pop, multiKill→combo, skillCast→skill, ultimateCast→ultimate, bossSpawned→boss_horn, bossCleared→boss_clear, bossFailed→fail …).
2. **변형·피치**: `juice.sound.hitVariants`(3)개 중 하나, 피치 1±`pitchJitter`(0.08). 고르는 값은 (틱, 대상 id)에서 계산(무작위 없음).
3. **겹침 상한**: 같은 sfx id는 `fx_map.sfxMinGapMs`(예: 40ms) 안에 다시 부르지 않고, 한 화면 프레임에 전체 `sfxMaxPerFrame`(예: 6)개까지.
   범위 처치처럼 Damage가 많을 때 소리가 뭉개지지 않게.
4. **배경음**: 해역이 바뀌면(`Backdrop`이 바꾸는 시점) `regions.json regions[].bgm`으로 `playBgm`. 보스 등장 중에는 그대로(전용 보스 BGM은 다음 단계).
5. **설정**: 효과음·배경음 볼륨(0 = 끔)은 UI 설정 → `AudioPort.sfxVolume/bgmVolume`. 렌더는 볼륨을 모른다.
6. **포트 주입**: `BattleGame(audio: AudioPort?)` — null이면 소리 없음(테스트·골든). 라이브/데모/부하 모두 같은 규칙.
7. **에셋**(art, S3): `apps/game/assets/audio/sfx/<id>[_<n>].ogg`, `audio/bgm/<id>.ogg` — CC0만(Kenney·OpenGameArt), `LICENSES.json`에 출처 URL. 없으면 어댑터가 조용히 넘긴다.
8. **어댑터**(platform 레인): `adapters/flame_audio_port.dart`(flame_audio 또는 audioplayers) — 이 스펙 범위 밖, 계약만 맞춘다.

## 수용 기준 — `apps/game/test/render/`
1. Given Damage·Kill·BossSpawned 기록 When 재생(SilentAudio) Then fx_map의 sfx id가 이벤트 순서대로 불린다.
2. Given 같은 대상에 Damage 10번 When 재생 Then 변형은 0~2만, 피치는 1±0.08 안, 같은 기록이면 같은 순서.
3. Given 한 틱에 Damage 20개 When 재생 Then 그 프레임 sfx 호출 ≤ `sfxMaxPerFrame`, 같은 id 간격 ≥ `sfxMinGapMs`.
4. Given stage 50 → 51 When 재생 Then `playBgm('bgm_coral')` 다음 `playBgm('bgm_storm')` 한 번씩.
5. Given audio null When 재생 Then 아무 일 없음(기존 테스트·골든 그대로).

## 문구
없음 — 설정 화면의 효과음·배경음 문구는 UI.

## 운영자 모드
`BattleGame.audioLog`(최근 sfx 20개)를 패널에 표시할 수 있게 값만 노출.

## 열린 질문 (S1)
- 계약 E(AudioPort) 채택 여부, `SilentAudio` 위치(testing.dart).
- 어댑터 패키지(flame_audio vs audioplayers)와 pubspec 의존 추가는 S1/플랫폼 결정.
