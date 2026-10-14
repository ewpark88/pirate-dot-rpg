# 계약 변경 요청: render-status (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-status.md`, 엔진 `docs/specs/battle-m3-legend.md`(main 19aa020)
- 상태: 제안 (S1 결정 대기)

## F. `EnemyView`에 상태 3개 (bool, 기본 false, JSON 없으면 false)
| 필드 | 뜻 (전설 onHit·장판) | 렌더 |
| --- | --- | --- |
| `slowed` | 감속 중 | 파란 색조 + 발밑 물방울 |
| `burning` | 화상(지속 피해) 중 | 머리 위 주황 불꽃 깜빡임 |
| `vulnerable` | 취약(받는 피해 증가) 중 | 머리 위 빨간 아래 화살표 |

- 기절은 이미 `stunned`. 끌어당김은 엔진이 x를 옮기므로 보간으로 보인다(필드 불필요).
- 이유: 상태는 프레임만 보고는 알 수 없다(감속은 "느린 이동"과, 화상은 "반복 Damage"와 구별 불가). 추측하지 않고 계약으로 받는다.
- 호환: 선택 필드 → 기존 기록·세이브 영향 없음(`BattleView`는 세이브에 없음). `toJson`은 false면 생략해도 된다(기록 크기).
