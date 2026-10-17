import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/battle_game.dart' hide IdleLevel;
import 'package:pirate_dot/render/battle_game.dart' as render show IdleLevel;
import 'package:pirate_dot/render/top/top_fast_sail.dart' show TopTexts;
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

/// 전장 위젯 주입점. null이면 Flame 전장([battleGameProvider]). UI 테스트·골든은 빈 상자로 바꿔
/// 렌더 레인의 그림 변화와 분리한다 (전장 골든은 render 레인 몫).
final battleViewBuilderProvider = Provider<WidgetBuilder?>((_) => null);

/// 설정 → 전장 타격감 옵션 (흔들림·번쩍임·진동·절전).
JuiceSettings juiceSettingsOf(Settings s) =>
    JuiceSettings(shake: s.shake, flash: s.flash, vibration: s.vibration, powerSave: s.powerSave);

/// UI 방치 단계 → 렌더 단계 (절전 화면 = 렌더 dim).
render.IdleLevel renderIdleOf(IdleLevel l) => switch (l) {
  IdleLevel.active => render.IdleLevel.active,
  IdleLevel.idle => render.IdleLevel.idle,
  IdleLevel.sleep => render.IdleLevel.dim,
};

/// 앱의 전장 하나. 처음 읽을 때 만든다 — 전장 위젯을 주입하면 home_screen이 읽지 않으므로 만들어지지 않는다.
/// 설정이 바뀌면 [JuiceSettings]를 바로 넘긴다. 운영자 패널 ‘렌더’ 묶음도 이것을 잡는다.
final battleGameProvider = Provider<BattleGame>((ref) {
  final game = BattleGame(
    feed: ref.read(battleFeedProvider),
    tables: ref.read(tablesProvider),
    settings: juiceSettingsOf(ref.read(gameStateProvider).settings),
    audio: ref.read(audioPortProvider),
  );
  // 설정의 배경음·효과음 끄기 → 음량 0 (켜면 1).
  void applyVolumes() {
    final s = ref.read(gameStateProvider).settings;
    ref.read(audioPortProvider)?.setVolumes(sfx: s.sfx ? 1 : 0, bgm: s.bgm ? 1 : 0);
  }

  applyVolumes();
  ref
    ..listen(gameStateProvider.select((s) => (s.settings.sfx, s.settings.bgm)), (_, _) => applyVolumes())
    ..listen(
      gameStateProvider.select((s) => (s.settings.shake, s.settings.flash, s.settings.vibration, s.settings.powerSave)),
      (_, _) => game.settings = juiceSettingsOf(ref.read(gameStateProvider).settings),
    )
    // 방치 단계·발열 단계의 원본은 UI(앱 루트 IdleGate·플랫폼) — 렌더는 받은 값을 따르고 스스로 세지 않는다(S3 요청 render-idle-thermal-link).
    ..listen(idleLevelProvider, (_, l) => game.idle.follow(renderIdleOf(l)), fireImmediately: true)
    ..listen(thermalLevelProvider, (_, t) => game.idle.heat.value = t.index, fireImmediately: true);
  return game;
});

/// 전장이 Flame 게임인가 (주입된 빈 상자가 아닌가). 운영자 ‘렌더’ 묶음은 이때만 쓸 수 있다.
final hasBattleGameProvider = Provider<bool>((ref) => ref.watch(battleViewBuilderProvider) == null);

/// 렌더 빠른 항해 돌파 연출 문구(렌더 레인은 ARB가 없다 — S3 TopTexts)를 지금 언어로 넣고 게임을 돌려준다.
BattleGame withTopTexts(BattleGame game, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  game.topTexts = TopTexts(
    start: l10n.uiFastSailStart,
    strike: l10n.uiFastSailStrike,
    finale: l10n.uiFastSailFinale,
    ended: l10n.uiFastSailEnded,
    // 현상금 B3 연출(S3): 수배 포스터 머리말 · 실패 문구.
    wanted: l10n.uiBountyWanted,
    fled: l10n.uiBountyFled,
  );
  return game;
}
