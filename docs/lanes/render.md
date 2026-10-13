# 레인: 렌더·타격감 (render) — S3 포수장

- 브랜치: `lane/render` · 폴더: `D:\Projects\pde-render` · 진척: `docs/progress/render.md`
- 소유 경로: `LANES.yaml` → `lanes.render.paths`
- 설계서: 4.4 전장 구성·타격감 규칙, 10장 아트 규격

## 목표
`apps/game/lib/render/battle_game.dart`의 Flame 전장을 채워, 전투 기록만 보고 “화면이 계속 터지는” 장면을 만든다.

## 기다리지 않고 쓰는 입력
- `fixtures/events/sample_battle.jsonl` — `decodeRecording()`으로 읽는 `RecordedTick(frame, events)` 목록 (지금은 합성본)
- 도트 팩 v0.2(32px) `D:\Projects\이미지참고용\해적도트원정대_도트_v0.2_32px`, 전투 v0.3 스프라이트 `해적도트원정대_전투_v0.3`
- `juice.json`, `fx_map.json` (이 레인 소유)

## 할 일 (M2)
1. 기록 재생기: 20Hz 프레임을 두 틱 사이 보간해 60fps로 그리기 (논리 해상도 320×180, 정수배 nearest)
2. 배·적(2프레임)·발사체(계열 8종)·이펙트 시트 재생, 슬롯 초상 + 쿨타임 덮개 + 발사 번쩍임
3. 타격감: 히트스톱(이벤트), 흔들림, 흰색 번쩍임, 넉백, 데미지 숫자(일반/치명/합산), 코인 분수 → 배로 빨려감
4. 상한: 이펙트 40, 숫자 24(넘치면 합침), 객체 풀링(프레임당 할당 0)
5. 설정의 흔들림·번쩍임·진동 끄기 반영, 절전 모드 30fps

## 완료 기준
- 이벤트 로그 재생 골든 테스트, 저사양 기기 60fps(M2 관문)
- 확인은 `flutter run -d chrome` + 골든 (실기기는 S4만 쓴다)
- 운영자 모드: 범위·히트박스 표시, FPS·이펙트 수 표시, juice 슬라이더가 읽을 수 있게 값 노출
- 명령을 내지 않는다(check가 render → ui/adapters import를 막는다)
- 2단계(M3~): 아트 레인으로 역할 교대
