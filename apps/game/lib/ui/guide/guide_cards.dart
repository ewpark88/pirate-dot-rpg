import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

// 가이드 v2 (docs/specs/ui-guide-v2.md, S1 승인 2026-10-17): 카드 = 무엇(제목) + 왜(한 줄) + 가리킬 곳.
// ① 첫 6단계 = 코어 tutorialStep 그대로(누름은 밝은 곳만). ② 튜토리얼 뒤 처음 만나는 시스템 카드 — 각 1회, 세이브 hints에 남긴다.
// 환생은 기존 '환생 가능' 큰 말풍선(RebirthReadyBubble)이 같은 일을 해서 여기 넣지 않는다.

/// 처음 만나는 시스템 카드 id (보이는 우선순위 순). 세이브 Settings.hints에 이 id가 남는다.
const guideIds = [
  'guide.sail',
  'guide.boss',
  'guide.fever',
  'guide.chest',
  'guide.newCrew',
  'guide.cargo',
  'guide.merge',
  'guide.promote',
  'guide.summon',
];

/// 카드마다 가리킬 곳(TutorialSpot id).
const guideSpots = {
  'guide.sail': ['sail.start'],
  'guide.boss': ['boss.gauge', 'boss.hp'],
  'guide.fever': ['fever.meter'],
  'guide.chest': ['chest'],
  'guide.newCrew': ['tab.crew'],
  'guide.cargo': ['cargo.bar'],
  'guide.merge': ['tab.crew', 'crew.mergeAll'],
  'guide.promote': ['tab.crew', 'crew.levelUp'],
  'guide.summon': ['tab.summon', 'summon.ten'],
};

/// 전투 중에 뜨는 카드 — 전장을 어둡게 하지 않고 3초 뒤 알약으로 접힌다. 그 상황이 끝나면 닫힌다.
const battleGuideIds = {'guide.boss', 'guide.fever'};

/// '안내 다시 보기'(ClearHints 접두어).
const guideHintPrefix = 'guide.';

/// 지금 조건이 맞는 시스템 카드 (본 기록과 무관 — 고를 때 거른다).
List<String> activeGuides(GameState s, GameTables t) {
  final b = s.battle;
  return [
    if (s.progress.sailHold) 'guide.sail',
    if (b?.bossActive ?? false) 'guide.boss',
    if ((b?.feverTicksLeft ?? 0) > 0) 'guide.fever',
    if (b?.chest != null) 'guide.chest',
    if (s.crews.containsKey('bones')) 'guide.newCrew',
    if (goldNearFull(s, t) || s.wallet.gold >= goldCapacity(s, t)) 'guide.cargo',
    if (canMergeAny(s, t)) 'guide.merge',
    if (s.crews.keys.any((id) => promoteStatus(s, t, id) == PromoteStatus.ok)) 'guide.promote',
    if (canSummon(s, t, 10)) 'guide.summon',
  ];
}

/// 조건이 맞는 id들 — 쉼표로 이은 글(20Hz 상태에서 값이 같으면 다시 계산하지 않게).
final _activeProvider = Provider<String>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(gameStateProvider.select((s) => activeGuides(s, t).join(',')));
});

/// 처음 만나는 시스템 카드를 켤지 (테스트 하네스가 끈다 — 가이드를 시험하는 테스트만 켠다).
final guidesEnabledProvider = Provider<bool>((_) => true);

/// 지금 떠 있는 시스템 카드 id (튜토리얼 중엔 없음). 한 번에 하나, 줄 서기.
final guideQueueProvider = NotifierProvider<GuideQueue, String?>(GuideQueue.new);

class GuideQueue extends Notifier<String?> {
  /// 이번 실행에 띄운 것 (세이브 hints가 늦게 와도 두 번 안 띄운다).
  final _shown = <String>{};
  String? _current;

  @override
  String? build() {
    if (ref.watch(tutorialStepProvider) != null || !ref.watch(guidesEnabledProvider)) return null;
    final active = ref.watch(_activeProvider).split(',').toSet();
    final seen = ref.watch(gameStateProvider.select((s) => s.settings.hints));
    final cur = _current;
    // 전투 카드는 그 상황이 끝나면 닫힌다. 나머지는 닫을 때까지 남는다.
    if (cur != null && (!battleGuideIds.contains(cur) || active.contains(cur))) return cur;
    _current = guideIds.where((id) => active.contains(id) && !seen.contains(id) && !_shown.contains(id)).firstOrNull;
    if (_current case final id?) {
      _shown.add(id);
      // 띄우는 순간 본 것으로 남긴다(앱을 꺼도 다시 안 뜬다). 빌드 중 명령을 보내지 않게 한 박자 뒤.
      scheduleMicrotask(() => ref.read(commandSinkProvider).send(MarkHint(id)));
    }
    return _current;
  }

  /// 카드 닫기(알겠어요·누를 곳을 누름).
  void close() {
    _current = null;
    ref.invalidateSelf();
  }

  /// 설정 '안내 다시 보기': 세이브의 guide.* 기록을 지우고(ClearHints) 이번 실행 기록도 비운다.
  void replay() {
    ref.read(commandSinkProvider).send(const ClearHints(guideHintPrefix));
    _shown.clear();
    close();
  }

  /// '안내를 끌까요? → 끄기': 남은 시스템 카드를 모두 본 것으로.
  void skipAll() {
    final sink = ref.read(commandSinkProvider);
    for (final id in guideIds) {
      if (_shown.add(id)) sink.send(MarkHint(id));
    }
    close();
  }
}

/// 카드 하나의 내용.
typedef GuideCard = ({
  String key,
  IconData icon,
  String title,
  String why,
  List<String> spots,
  bool ack,
  bool block,
  bool battle,
});

/// 지금 보일 카드: 튜토리얼 단계([step]) 또는 시스템 카드([id]). 둘 다 없으면 null.
GuideCard? guideCardFor(AppLocalizations l, {int? step, String? id}) {
  if (step != null) {
    final (icon, title, why) = switch (step) {
      1 => (Icons.sailing_rounded, l.uiGuideStep1Title, l.uiGuideStep1Why),
      2 => (Icons.build_rounded, l.uiGuideStep2Title, l.uiGuideStep2Why),
      3 => (Icons.sports_martial_arts_rounded, l.uiGuideStep3Title, l.uiGuideStep3Why),
      4 => (Icons.auto_awesome_rounded, l.uiGuideStep4Title, l.uiGuideStep4Why),
      5 => (Icons.merge_type_rounded, l.uiGuideStep5Title, l.uiGuideStep5Why),
      _ => (Icons.flag_rounded, l.uiGuideStep6Title, l.uiGuideStep6Why),
    };
    return (
      key: 'step.$step',
      icon: icon,
      title: title,
      why: why,
      spots: [...?tutorialSpots[step]],
      ack: tutorialAckSteps.contains(step),
      // 누를 곳이 있는 단계는 밝은 곳만 누르게(S1 결정 (a)). 확인 단계는 카드만.
      block: !tutorialAckSteps.contains(step),
      battle: false,
    );
  }
  if (id == null) return null;
  final (icon, title, why) = switch (id) {
    'guide.sail' => (Icons.sailing_rounded, l.uiGuideSailTitle, l.uiGuideSailWhy),
    'guide.boss' => (Icons.sports_martial_arts_rounded, l.uiGuideBossTitle, l.uiGuideBossWhy),
    'guide.fever' => (Icons.local_fire_department_rounded, l.uiGuideFeverTitle, l.uiGuideFeverWhy),
    'guide.chest' => (Icons.redeem_rounded, l.uiGuideChestTitle, l.uiGuideChestWhy),
    'guide.newCrew' => (Icons.person_add_alt_1_rounded, l.uiGuideNewCrewTitle, l.uiGuideNewCrewWhy),
    'guide.cargo' => (Icons.inventory_2_rounded, l.uiGuideCargoTitle, l.uiGuideCargoWhy),
    'guide.merge' => (Icons.merge_type_rounded, l.uiGuideMergeTitle, l.uiGuideMergeWhy),
    'guide.promote' => (Icons.upgrade_rounded, l.uiGuidePromoteTitle, l.uiGuidePromoteWhy),
    _ => (Icons.auto_awesome_rounded, l.uiGuideSummonTitle, l.uiGuideSummonWhy),
  };
  return (
    key: id,
    icon: icon,
    title: title,
    why: why,
    spots: guideSpots[id] ?? const [],
    ack: true,
    block: false,
    battle: battleGuideIds.contains(id),
  );
}

/// 지금 카드가 가리키는 id들 (TutorialSpot이 테두리를 그린다). 튜토리얼 단계가 먼저.
final guidePointedProvider = Provider<Set<String>>((ref) {
  final step = ref.watch(tutorialStepProvider);
  if (step != null) return {...?tutorialSpots[step]};
  final id = ref.watch(guideQueueProvider);
  return {...?guideSpots[id]};
});
