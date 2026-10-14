# 계약 변경 요청: render-hud (render → S1)

- 요청: S3 render · 2026-10-14 · 관련: `docs/specs/render-quality-v1.md` 규칙 8 (캔버스 안 HUD, 기준 battle_ship.gif)
- 상태: 제안

## H. `BattleView`에 HUD 값 3개 (모두 선택, JSON 없으면 기본값)
| 필드 | 형 | 기본 | 뜻 |
| --- | --- | --- | --- |
| `wave` | int | 1 | 지금 파(스테이지 표시 `12-2`의 2) |
| `rage` | double | 0 | 함성 게이지 0~1 |
| `gold` | BigNum | 0 | 보유 골드(왼쪽 위 숫자) |

- 이유: 기준 화면은 HUD를 전장 캔버스 안에 그린다. 렌더는 BattleView만 보므로(ui·adapters import 금지) 이 값들이 프레임에 있어야 한다.
  기록 재생(데모·부하·골든)에서도 같은 HUD가 나온다.
- 호환: 선택 필드 → 기존 기록 호환. `BattleView`는 세이브에 없음. gold는 경제 상태지만 HUD 표시용 사본이라 매 틱 복사만.
