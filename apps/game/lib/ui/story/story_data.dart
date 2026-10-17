import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

// 시나리오 (사용자 2026-10-17): 처음 시작 오프닝 컷 · 보스 등장 대화. 대본·표는 S2 story.json이 오면 거기서 —
// 그 전에는 이 가짜 대본(임시 어댑터)으로 화면 골격을 만든다. 글은 ARB(ui) 키.

/// 오프닝 한 컷: 그림 종류 + 글.
enum OpeningArt { sea, octo, bosses, crew, sail }

typedef OpeningCut = ({OpeningArt art, String text});

/// 보스 대화 한 줄: 누가(옥토 / 보스) + 글.
enum Speaker { octo, boss }

typedef StoryLine = ({Speaker who, String text});

/// 가짜 대본 (S2 story.json 전 임시).
abstract interface class StoryScript {
  List<OpeningCut> opening(AppLocalizations l);

  /// [bossId]가 처음 나올 때 대화. 없으면 빈 목록(대화 없음).
  List<StoryLine> bossIntro(AppLocalizations l, String bossId);
}

class FakeStoryScript implements StoryScript {
  const FakeStoryScript();

  @override
  List<OpeningCut> opening(AppLocalizations l) => [
    (art: OpeningArt.sea, text: l.uiStoryOpen1),
    (art: OpeningArt.octo, text: l.uiStoryOpen2),
    (art: OpeningArt.bosses, text: l.uiStoryOpen3),
    (art: OpeningArt.crew, text: l.uiStoryOpen4),
    (art: OpeningArt.sail, text: l.uiStoryOpen5),
  ];

  @override
  List<StoryLine> bossIntro(AppLocalizations l, String bossId) => [
    (who: Speaker.boss, text: l.uiStoryBossTaunt),
    (who: Speaker.octo, text: l.uiStoryOctoReply),
  ];
}

final storyScriptProvider = Provider<StoryScript>((_) => const FakeStoryScript());

/// 오프닝·보스 대화를 켤지 — UI 시험 하네스가 끈다(이야기를 시험하는 테스트만 켠다).
final storyEnabledProvider = Provider<bool>((_) => true);

/// 대화 한 줄이 자동으로 넘어가는 시간 (전투는 그동안 계속 — 방치형).
const storyLineFor = Duration(milliseconds: 2800);

/// 본 기록(세이브 hints): 오프닝 · 보스별 대화.
const storyOpeningHint = 'story.opening';
String storyBossHint(String bossId) => 'story.boss.$bossId';
