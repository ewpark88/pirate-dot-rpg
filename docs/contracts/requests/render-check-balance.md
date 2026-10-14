# 요청: check `--full`에 `balance crews --quick` 넣기 (render → S1, tool/은 shared)

- 요청: S3 render · 2026-10-14 · 관련: `docs/specs/render-balance-crews.md` 결정 Q3
- 측정: `dart run game_cli balance crews --quick` 약 4.7초(dart 시작 포함, main cb0ba99 테이블에서 종료 0). 조건(≤20초) 충족.
- 종료 코드: 0 통과 · 1 위반(±10% 밖 또는 조합 상위 1% > 중앙값×1.3) · 3 측정 오류(적 처치·배 침몰·25 배수 스테이지).
  2는 game_cli 공통 "미구현"이라 balance crews는 쓰지 않는다 — 아래 코드는 2를 실패로 다룬다(구현돼 있으므로).

## 붙일 코드 (`tool/check.dart`)

`stages` 목록의 `('밸런스 스모크', _balanceSmoke),` 다음 줄:

```dart
    if (full) ('선원 균형 (balance crews --quick)', _balanceCrews),
```

`_balanceSmoke` 아래에 함수:

```dart
/// 설계서 4.8 선원 균형: 레벨 45 점수표 ±10% + 6명 조합 50개 상위 1% ≤ 중앙값×1.3 (약 5초).
/// 실패하면 표 전체를 보여 준다 — 어느 선원이 몇 배인지 바로 보이게.
Future<_Outcome> _balanceCrews() async {
  final r = await _run('dart', ['run', 'game_cli', 'balance', 'crews', '--quick']);
  if (r.ok) return const _Outcome(ok: true, note: '레벨 45 · 조합 50');
  final why = switch (r.exitCode) {
    1 => '균형 위반 — ✗ 칸·조합 배율을 보고 skills.json(families power·ladder.power·legends.powerScale)을 조정',
    3 => '측정 오류 — 적이 죽었거나 배가 가라앉음(stage·hull 옵션 확인)',
    _ => '실행 실패',
  };
  return _Outcome(ok: false, exitCode: r.exitCode, output: '$why\n${r.output}');
}
```

## 확인 방법
- 지금 main: `dart run tool/check.dart --full` → `▶ 선원 균형 (balance crews --quick) ... ok (약 5s) — 레벨 45 · 조합 50`.
- 일부러 깨 보기: `skills.json` direct `attack.power`를 ×1.3 → check 실패, 표에 direct 5명 ✗.
