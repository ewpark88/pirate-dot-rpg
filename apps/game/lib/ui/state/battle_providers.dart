import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 전장 위젯 주입점. null이면 Flame 전장([battleGameProvider]). UI 테스트·골든은 빈 상자로 바꿔
/// 렌더 레인의 그림 변화와 분리한다 (전장 골든은 render 레인 몫).
final battleViewBuilderProvider = Provider<WidgetBuilder?>((_) => null);

/// 설정 → 전장 타격감 옵션 (흔들림·번쩍임·진동·절전).
JuiceSettings juiceSettingsOf(Settings s) =>
    JuiceSettings(shake: s.shake, flash: s.flash, vibration: s.vibration, powerSave: s.powerSave);

/// 앱의 전장 하나. 처음 읽을 때 만든다 — 전장 위젯을 주입하면 home_screen이 읽지 않으므로 만들어지지 않는다.
/// 설정이 바뀌면 [JuiceSettings]를 바로 넘긴다. 운영자 패널 ‘렌더’ 묶음도 이것을 잡는다.
final battleGameProvider = Provider<BattleGame>((ref) {
  final game = BattleGame(
    feed: ref.read(battleFeedProvider),
    tables: ref.read(tablesProvider),
    settings: juiceSettingsOf(ref.read(gameStateProvider).settings),
  );
  ref.listen(
    gameStateProvider.select((s) => (s.settings.shake, s.settings.flash, s.settings.vibration, s.settings.powerSave)),
    (_, _) => game.settings = juiceSettingsOf(ref.read(gameStateProvider).settings),
  );
  return game;
});

/// 전장이 Flame 게임인가 (주입된 빈 상자가 아닌가). 운영자 ‘렌더’ 묶음은 이때만 쓸 수 있다.
final hasBattleGameProvider = Provider<bool>((ref) => ref.watch(battleViewBuilderProvider) == null);
