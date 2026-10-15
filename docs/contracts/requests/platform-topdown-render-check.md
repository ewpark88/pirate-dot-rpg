# 점검: 탑다운 렌더(T2)가 쓰는 엔진 값·이벤트 (platform S5 → S3·S2)

- 2026-10-15 · main a4037f6 기준(T1 머지 뒤) · 렌더 현재: `render/top/`에 바다·배(shipHeading)만.
- 좌표: 전장 270×480, 왼쪽 위 (0,0), 배 중심 `BattleView.shipX/shipY`(= waves.top 135·240, 고정).
  카메라 = 배 중심 가운데, 보이는 사각형 `waves.top.viewWidth × viewHeight`(180×320). 화면 좌표 = (x − shipX) × 배율 + 화면 중심.

## 있는 것 (그대로 쓰면 됨)
| 그릴 것 | 값 | 비고 |
| --- | --- | --- |
| 모드 | `BattleView.mode == 'top'` | side면 옛 렌더 |
| 배 위치·방향 | `shipX`, `shipY`, `shipHeading`(0 = 위, 지금은 늘 0) | 크기는 `ship_tiers.tierAt(stage).topRadius`(28·29·32·32)가 충돌 반경 |
| 적 위치·방향 | `EnemyView.x/y/heading`(배를 향하는 각, atan2(dy, dx)) | 원을 도는 보스도 배를 본다. 층(air·underwater)은 위치 같고 그림만 다르게 |
| 무리 등장 | 첫 틱 위치가 화면 밖(접근 원 206 밖) | 접근 원 밖에서는 ×5로 빠르게 다가온다('해류') — 꼬리 물보라 연출 권장 |
| 보스 | `boss: true`, 위쪽 화면 밖 → standoff 100 원에서 정지·회전(초당 12°) | 촉수 `<boss>_tentacle`는 standoff 원 위 고정 |
| 선원 공격 | `AttackFired.fromX/fromY`(배 둘레 포구), `angle`(발사 방향), `x/y`(조준점), `targetIds` | 관통 = from → 조준점 방향 광선, 충격 = x/y가 배 중심(고리), 강습 = angle 방향 부채꼴 |
| 피해·처치 | `Damage.targetId`(적 위치는 뷰에서), `Kill.x/y`, `AoeDamageSum.x/y` | 금화는 Kill 위치 → 배 중심으로 |
| 장판 | `ZoneSpawned.x/y/radius/ticks` | 원 |
| 스킬 | `SkillCast.x/y`(배 대상 스킬은 배 중심), `scope: screen`이면 화면 전체 | 방향은 배 중심 → x/y로 계산 |
| 궁극기 | `UltimateCast` | 중심 = 배 중심, 대상 = 카메라 사각형 안 전부 |
| 보스 원거리 공격 | `BossFired.x/y`(보스 위치) | 배 중심으로 날아오는 발사체 |
| 밀어내기 | 다음 틱 적 위치가 배에서 바깥쪽(방사)으로 뜀 | 보간 |

## 빠진 것 (엔진 — S2 계약/경제)
1. **보물상자 위치**: `economy/chest.dart`가 옆모습 필드(`field.width × xMin~xMax`, `laneY.surface`)로 놓는다.
   탑다운에서는 카메라 사각형 안(배 둘레 밖)에 놓아야 한다 → S2: `battle.mode == 'top'`이면 waves.top 기준으로 놓기.
2. **배가 맞은 방향**: `ShipDamaged`에 위치가 없다. 탑다운은 어느 쪽에서 맞았는지가 보여야 한다(피격 반짝임·흔들림 방향)
   → 제안: 선택 키 `fromX/fromY`(때린 적 위치, 보스 용암은 null). combat.moveFoes 훅에서 채울 수 있다(S5가 해도 됨).
3. (선택) `SkillCast.angle`: 배 중심 → x/y로 렌더가 계산 가능하므로 없어도 된다.

## 렌더(S3) 확인 부탁
- 위 '있는 것'으로 적·보스·공격 8계열·금화·장판을 그릴 때 더 필요한 값이 있으면 이 문서에 줄을 더해 주세요(S5가 엔진 쪽을 붙입니다).
- 운영자 토글(S4 요청서)은 '렌더 준비 중' 표시로 먼저 들어간다(S1 결정 b).
