# ADR-0005: ARB 키는 레인 접두어 + camelCase

- 날짜: 2026-10-13 · 상태: 채택

## 맥락
설계서 5.1은 `hero.knight.name` 같은 점 표기 키를 예로 들지만, `flutter gen-l10n`은 키를 Dart 메서드 이름으로 만들므로 점을 쓸 수 없다.

## 결정
- 키 = `<파트 이름><PascalCase 내용>`: `crewOctoName`, `shipPartCannon`, `battleComboDouble`, `uiTabVoyage`, `opPanelTitle`
- 파트 파일 `apps/game/lib/l10n/parts/<파트>.<ko|en>.arb`의 파트 이름이 곧 접두어다. `merge_arb`가 접두어·ko/en 일치·중복을 검사한다.
- 파트 소유: crew·ship·econ → economy, battle → battle, ui·op → ui, platform → platform.

## 결과
- 테이블의 `nameKey`도 이 형식. check가 테이블이 참조하는 키가 ARB에 있는지 확인한다.
