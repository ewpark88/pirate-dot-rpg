# HD 카툰 기준서 (디자인 개편 ④)

사용자 결정(2026-10-17): 몬스터·보스·배를 모두 HD 카툰으로 바꾼다. 기준 그림은 쿵푸할매 서바이버
(`D:\Projects\이미지참고용\쿵푸할매 서바이버\`)와 시범 4종(`apps/game/test/render/goldens/hd_trial.png`, 움직임은 `hd_trial_anim.png`)이다.

## 1. 방식: 코드 벡터를 기기 해상도로 굽는다

- 그림은 **Dart 코드 벡터**다(`apps/game/lib/render/hd/`). AI 생성·유료 도구는 쓰지 않는다. 우리가 직접 쓴 코드라 LICENSES는 OWN이고, PNG 자산이 아니라서 `LICENSES.json` 항목도 필요 없다.
- 실행 중에 종이 처음 보이면 `HdSheets`가 한 장으로 굽는다. 시트는 8장 × 2방향이고, `toImageSync`라서 비동기가 없고 골든도 같은 그림이다.
  - 해상도는 단위당 기기 px(`snap`)다. 그래서 폰과 태블릿 모두 선명하다.
  - 칸 한 변은 최대 512px다.
- `hd_species.dart`에 없는 종은 지금 도트로 그린다. 섞여도 동작하므로 한 종씩 바꿔 넣으면 된다.

## 2. 그림 규칙

| 항목 | 규칙 |
|---|---|
| 시점 | 정면 3/4이고 **왼쪽을 본다**. 회전하지 않는다. 오른쪽으로 갈 때는 굽기가 좌우를 뒤집는다(거의 위아래로 갈 때는 지난 방향을 유지한다). |
| 비율 | 2등신 덩어리. 몸통이 크고 눈은 크게(몸 폭의 20~30%) 그린다. |
| 외곽선 | `HdKit.ink`: 색 `0xFF1A1424`(아주 어두운 보라), 두께는 r의 11%이고 최소 2.5px. 둥근 끝과 둥근 이음을 쓴다. 덩어리마다 두른다. 작은 부품(부리·뿔·지느러미 끝)은 로 얇게 해서 색이 묻히지 않게 한다. |
| 칠 | `blob`을 쓴다. 위 밝은 색 → 아래 어두운 색 세로 그라데이션이다. 반투명(해파리 등)만 원형 그라데이션을 쓴다. |
| 광택 | `blob(gloss: true)`: 왼쪽 위 흰 타원(알파 0.6)과 반짝 점 하나. 큰 덩어리(몸통·머리·집게)에만 넣는다. |
| 눈 | `eye`: 흰자 + 검은 눈동자 + 반짝 두 점. 적과 보스는 `angry: true`(눈썹)를 쓰고 귀여운 잡몹은 없이 그린다. `look`으로 시선을 잡는다. |
| 입 | `smile`(귀여움), `mouth` + `tooth`(사나움). |
| 볼 | `cheeks`: 귀여운 종만. |
| 팔레트 | 채도가 높은 원색이다. 밝은 색과 어두운 색은 같은 색상에서 명도를 30~40% 내린다(예: 빨강 `FF5A48` → `C0281E`). 바다(파랑·청록)와 겹치지 않게 몸 색은 빨강·주황·보라·분홍·노랑·초록을 우선 쓴다. 파랑 몸이면 외곽선과 붉은 포인트로 띄운다. |
| 보스 | `crown`(금관) 또는 큰 뿔·흉터 같은 표시를 넣는다. 화난 눈과 이빨을 쓴다. |
| 그림자 | 굽기가 자동으로 깐다(`HdSpecies.ground`). 날짐승은 ground를 크게 잡는다(떠 보이게). |

## 3. 크기 규격

- 전장 자리 크기는 지금 도트 칸과 같다(잡몹 16단위, 보스는 `td_boss` 시트 칸 폭 56~88). 그래서 맞는 자리와 체력 막대 위치가 그대로다.
- `HdSpecies.extent`는 그림이 원점에서 r의 몇 배까지 뻗는지다. 굽기 칸 = 2·extent·r이다. 몸통이 칸의 60~70%를 채우게 extent를 1.3~1.5로 잡는다. 칸을 넘는 부분은 잘린다.

## 4. 움직임 규칙

- 한 고리는 0.8초이고 0.1초씩 8장이다. 반드시 `k.wave(t, n, off)`만 쓴다. 고리에 n번 오르내려서 8장째가 1장째로 이어진다. `math.sin(t / 200)`처럼 고리에 안 맞는 주기는 쓰지 않는다.
- 숨쉬기: 몸 1~5% 부풀기(`wave(t, 1)`).
- 꿈틀: 촉수와 다리는 마디마다 `off`를 다르게 준다.
- 공격 부위(집게·입·꼬리): 1~2번 까딱.
- 게임 안 흔들림·등장·찌그러짐·번쩍임은 `TopEnemies`가 시트 위에 그대로 얹는다(종 코드에서 하지 않는다).

## 5. 렌더 연결 (S3)

- `HdSheets.sheet(kind, boss, world, density)`: 시트가 없으면 굽고, 있으면 캐시를 쓴다(최대 14장, 오래 안 쓴 것부터 버림).
- `TopEnemies`: HD 시트가 있으면 drawAtlas 묶음은 같게 하고 회전 대신 ±0.06 흔들기, `FilterQuality.medium`을 쓴다.

## 6. 한 종 추가 방법 (예시: 게)

1. `apps/game/lib/render/hd/species/<kind>.dart`를 만든다. kind는 엔진 적 id다(`regions` 적, 보스는 `fx_map bossLook` 키). 예시는 `species/crab.dart`다.

```dart
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

const crab = HdSpecies(_crab, extent: 1.35, ground: 0.7);

void _crab(HdKit k, Canvas c, double r, double t) {
  final bob = k.wave(t, 2) * r * 0.04;           // 움직임은 wave로만
  // 뒤 → 앞 순서로: 다리(limb) → 집게(pincer) → 몸통(blob) → 눈(eye) → 입(smile) → 볼(cheeks)
  k.blob(c, Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.5, height: r * 1.05)),
      const Color(0xFFFF8A6A), const Color(0xFFC0281E));
  k.eye(c, Offset(-r * 0.3, -r * 0.55 + bob), r * 0.34);
}
```

2. `hd/hd_species.dart`의 `hdEnemies`(보스는 `hdBosses`)에 `'<kind>': <이름>,` 한 줄을 넣는다.
3. 확인:
   - `apps/game/test/render/hd_trial_test.dart`와 `hd_trial_anim_test.dart`의 `_kinds`에 넣고 `flutter test --update-goldens`로 한 장 보기와 8장 띠를 본다.
   - 게임 안 모습은 `top_golden_test`에서 그 종이 나오는 해역으로 본다.
4. 부품이 모자라면(날개·껍데기·지느러미 등) 종 파일 안에 그리지 말고 `HdKit`에 부품 함수로 넣는다(S3에 요청하거나 리뷰 브랜치로). 같은 부품은 모든 종이 같이 쓴다.

부품 목록(`HdKit`): `blob`, `shine`, `eye`, `smile`, `mouth`, `tooth`, `cheeks`, `limb`, `tentacle`, `pincer`, `tail`, `crown`, `spots`, `shadow`, `wave`.

## 7. 나눔

- 보스(대보스 6 → 해역·중간 → 순환 23)와 배는 S3가 맡는다.
- 몬스터 27종은 S2·S5가 이 도구로 그린다. 종 파일은 리뷰 브랜치(`review/hd-<묶음>`)로 내고 S1이 합친다(`hd/species/`는 render 레인 경로).
