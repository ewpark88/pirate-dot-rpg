# ADR-0001: Dart pub workspace 모노레포

- 날짜: 2026-10-13 · 상태: 채택

## 결정
루트 `pubspec.yaml`의 `workspace:`에 `packages/game_data`, `packages/game_core`, `packages/game_cli`, `apps/game`, `tool`을 둔다.
각 멤버는 `resolution: workspace`. `flutter pub get`을 루트에서 한 번 하면 전부 해결된다.

## 이유
- 설계서 6.1. 패키지 경계가 곧 의존 규칙이라 `check_deps`가 단순해진다.
- 버전 하나로 고정되어 레인 사이 의존성 충돌이 없다.

## 결과
- Flutter SDK가 `meta` 등을 고정하므로 순수 Dart 패키지의 제약도 그에 맞춘다(`meta ^1.16.0`).
- Dart 3.12에 맞춰 `very_good_analysis ^10.3.0`(11.x는 Dart 3.13 필요). SDK를 올릴 때 함께 올린다.
- 포맷 폭 120 (`analysis_options.yaml`의 `formatter.page_width`).
