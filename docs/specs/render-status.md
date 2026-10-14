# 스펙: 렌더 — 적 상태 표시 (감속·화상·취약)

- 상태: 초안 — 승인 대기 · 레인: render(S3) · 설계서 절: 4.4 타격감, 4.3 전설 고유 능력(엔진 `battle-m3-legend`)
- 계약 요청: `docs/contracts/requests/render-status.md` (EnemyView.slowed·burning·vulnerable)

## 목적
- 시원한가: 전설 선원의 능력이 "보인다" — 맞은 적이 얼고, 타고, 약해진 게 한눈에.
- 피로가 없는가: 표시는 작고(2~3px) 단색, 상태가 여러 개면 위에서부터 한 줄로. 번쩍임 끄기면 불꽃 깜빡임도 고정.
- 공정한가: 기록의 상태 필드만 보고 그린다.

## 규칙
1. **감속**(`slowed`): 적 색(또는 스프라이트)에 파란 색조 필터, 발밑 1px 물방울 2개가 `fx_map.status.slowed.periodMs`마다 떨어진다.
2. **화상**(`burning`): 머리 위 주황 2×2 불꽃 2개가 번갈아 깜빡임(번쩍임 끄기면 깜빡이지 않고 켜짐).
3. **취약**(`vulnerable`): 머리 위 빨간 3px 아래 화살표.
4. **겹침**: 기절 별·화상·취약은 머리 위 한 줄(왼→오: 기절·화상·취약), HP 바 위. 보호막·tier 테두리와 겹치지 않게 테두리 바깥 위쪽.
5. **수치**: `fx_map.status`(색·주기·크기).

## 수용 기준 — `apps/game/test/render/`
1. Given `slowed` true인 적 When 그림 Then 파란 색조 픽셀(스프라이트·플레이스홀더 둘 다), false가 되면 원래 색.
2. Given `burning` When 시간이 흐름 Then 불꽃이 깜빡이고, 번쩍임 끄기면 계속 켜짐.
3. Given `vulnerable` When 그림 Then 머리 위 빨간 화살표 픽셀.
4. Given 기절+화상+취약 When 그림 Then 세 표시가 한 줄로 겹치지 않는다(위치 테스트).

## 문구
없음.

## 운영자 모드
S1 `OpSetWave`·전설 선원 출전으로 엔진이 상태를 내면 라이브로 보인다.

## 열린 질문 (S1)
- 계약 F 채택 여부(필드 이름).
