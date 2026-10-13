/// 운영자 모드 빌드 플래그 (docs/GAME_DESIGN.md 6.10).
///
/// `flutter build apk --dart-define=OPERATOR=true` 내부 테스트 빌드에서만 true.
/// 상수라서 스토어 빌드에서는 `if (kOperator) { ... }` 안의 코드가 컴파일 때 빠진다.
/// operator/ 밖에서는 반드시 이 가드 안에서만 운영자 코드를 부른다(tool/check가 검사).
const bool kOperator = bool.fromEnvironment('OPERATOR');
