import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/story/story_text.dart';

// 시나리오 (사용자 2026-10-17): 처음 시작 오프닝 컷 · 보스 등장 대화. 대본·표는 S2 story.json이 오면 거기서 —
// 대사 키는 battle ARB(S2) — story_text.dart가 글로 바꾼다.

/// 오프닝 한 컷: 그림 번호(0~4, S3 HdOpeningBackdrop) + 1~2줄.
typedef OpeningCut = ({int art, List<String> lines});

/// 대사 한 줄: 누가(해설 · 보스 · 옥토 · 본즈) + 글.
enum Speaker { narrator, boss, octo, bones }

typedef StoryLine = ({Speaker who, String text});

abstract interface class StoryScript {
  List<OpeningCut> opening(AppLocalizations l);

  /// [bossId]가 처음 나올 때 대화([stage]로 공용 대사 중 하나를 고른다). 없으면 빈 목록.
  List<StoryLine> bossIntro(AppLocalizations l, String bossId, int stage);

  /// 대사 한 줄이 저절로 넘어가는 시간 · 오프닝 한 컷 시간.
  Duration get lineFor;
  Duration get cutFor;
}

/// story.json(S2, docs/specs/economy-story.md) 대본.
class TableStoryScript implements StoryScript {
  const TableStoryScript(this.tables);

  final GameTables tables;

  StoryTable get _t => tables.story;

  static Speaker _who(String id) => Speaker.values.firstWhere((s) => s.name == id, orElse: () => Speaker.narrator);

  @override
  List<OpeningCut> opening(AppLocalizations l) => [
    for (final (i, c) in _t.opening.indexed)
      (
        art: (int.tryParse(c.art.split('_').last) ?? i + 1) - 1,
        lines: [for (final line in c.lines) storyText(l, line.nameKey)],
      ),
  ];

  @override
  List<StoryLine> bossIntro(AppLocalizations l, String bossId, int stage) {
    final def = tables.regions.bosses[bossId];
    if (def == null) return const [];
    return [for (final line in _t.bossIntro(def, stage)) (who: _who(line.who), text: storyText(l, line.nameKey))];
  }

  @override
  Duration get lineFor => Duration(milliseconds: (_t.lineSec * 1000).round());

  @override
  Duration get cutFor => Duration(milliseconds: (_t.openingCutSec * 1000).round());
}

final storyScriptProvider = Provider<StoryScript>((ref) => TableStoryScript(ref.watch(tablesProvider)));

/// 오프닝·보스 대화를 켤지 — UI 시험 하네스가 끈다(이야기를 시험하는 테스트만 켠다).
final storyEnabledProvider = Provider<bool>((_) => true);

/// 대화 한 줄이 자동으로 넘어가는 시간 기본값 (표가 정한다 — 시험이 쓴다).
const storyLineFor = Duration(milliseconds: 2500);

/// 본 기록(세이브 hints): 오프닝 · 보스별 대화.
const storyOpeningHint = 'story.opening';
String storyBossHint(String bossId) => 'story.boss.$bossId';
