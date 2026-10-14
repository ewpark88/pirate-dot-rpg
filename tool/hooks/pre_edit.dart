// PreToolUse(Edit|Write): 테스트 기대값(세이브 픽스처·골든 이미지)을 에이전트가 고치지 못하게 막는다.
// 테스트를 통과시키려고 기대값을 바꾸는 것을 막기 위해서다. 갱신은 사람이 명령으로만 한다.
import 'dart:io';

import 'hook_io.dart';

const protected = {
  'test/fixtures/saves/': '세이브 픽스처는 사람이 `dart run game_cli fixtures --saves`로만 갱신합니다',
  '/goldens/': '골든 이미지는 사람이 `flutter test --update-goldens`로만 갱신합니다',
};

Future<void> main() async {
  final input = await readHookInput();
  final root = hookRoot(input);
  final path = editedPath(input, root);
  if (path == null) exit(0);
  for (final e in protected.entries) {
    if (path.contains(e.key)) {
      block(
        '$path 는 보호된 테스트 기대값입니다. ${e.value}.\n'
        '테스트가 실패하면 기대값이 아니라 코드를 고치세요. 기대값 변경이 맞다면 사람에게 요청하세요.',
      );
    }
  }
}
