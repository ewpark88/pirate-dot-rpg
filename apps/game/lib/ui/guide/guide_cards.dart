import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

// 가이드 v3 (S1 승인 2026-10-17, 스토리보드 docs/specs/ui-guide-v3/): 옥토 선장이 말풍선으로 한 마디씩 — 짧은 해요체 대화.
// ① 첫 6단계 = 코어 tutorialStep 그대로(누름은 밝은 곳만, 어둡게는 첫 두 단계만). 한 단계 안에서도 화면 상태(시트 열림·파밍)에 맞는 말을 고른다.
// ② 튜토리얼 뒤 처음 만나는 시스템 — 각 1회, 세이브 hints에 남긴다. 예전 말풍선(보스 다시 도전·환생)도 여기로 합쳤다.

/// 처음 만나는 시스템 id (보이는 우선순위 순). 세이브 Settings.hints에 이 id가 남는다.
const guideIds = [
  'guide.sail',
  'guide.boss',
  'guide.bossTrait',
  'guide.fever',
  'guide.chest',
  'guide.bossRetry',
  'guide.rebirth',
  'guide.newCrew',
  'guide.cargo',
  'guide.merge',
  'guide.promote',
  'guide.summon',
  'guide.collect',
  'guide.shipSkin',
];

/// 예전 말풍선의 본 기록 → 같은 안내로 본다(옛 세이브에서 다시 뜨지 않게).
const _legacyHints = {'guide.bossRetry': 'boss.bubble', 'guide.rebirth': 'rebirth.bubble'};

/// 안내마다 가리킬 곳(TutorialSpot id).
const guideSpots = {
  'guide.sail': ['sail.start'],
  'guide.boss': ['boss.gauge', 'boss.hp'],
  'guide.fever': ['fever.meter'],
  'guide.chest': ['chest'],
  'guide.bossRetry': ['boss.challenge'],
  'guide.rebirth': ['tab.voyage', 'rebirth.open'],
  'guide.newCrew': ['tab.crew'],
  'guide.cargo': ['cargo.bar'],
  'guide.merge': ['tab.crew', 'crew.mergeAll'],
  'guide.promote': ['tab.crew', 'crew.levelUp'],
  'guide.summon': ['tab.summon', 'summon.ten'],
  'guide.bossTrait': ['boss.gauge'],
  'guide.collect': ['tab.crew', 'collect.claim'],
  'guide.shipSkin': ['tab.ship', 'ship.skin'],
};

/// 전투 중에 뜨는 안내 — 어둡게 하지 않고 손가락 없이 말만, 3초 뒤 초상만 남게 접힌다. 그 상황이 끝나면 닫힌다.
const battleGuideIds = {'guide.boss', 'guide.bossTrait', 'guide.fever'};

/// '안내 다시 보기'(ClearHints 접두어).
const guideHintPrefix = 'guide.';

/// 지금 조건이 맞는 시스템 안내 (본 기록과 무관 — 고를 때 거른다).
List<String> activeGuides(GameState s, GameTables t) {
  final b = s.battle;
  final p = s.progress;
  return [
    if (p.sailHold) 'guide.sail',
    if (b?.bossActive ?? false) 'guide.boss',
    if (_traitBoss(s, t) != null) 'guide.bossTrait',
    if ((b?.feverTicksLeft ?? 0) > 0) 'guide.fever',
    if (b?.chest != null) 'guide.chest',
    if (p.farming && !(b?.bossActive ?? false)) 'guide.bossRetry',
    if (p.rebirths == 0 && _rebirthReady(s, t)) 'guide.rebirth',
    if (s.crews.containsKey('bones')) 'guide.newCrew',
    if (goldNearFull(s, t) || s.wallet.gold >= goldCapacity(s, t)) 'guide.cargo',
    if (canMergeAny(s, t)) 'guide.merge',
    if (s.crews.keys.any((id) => promoteStatus(s, t, id) == PromoteStatus.ok)) 'guide.promote',
    if (canSummon(s, t, 10)) 'guide.summon',
    if (collectionRewardsReady(s, t) > 0) 'guide.collect',
    if (s.ship.skinsOwned.isNotEmpty) 'guide.shipSkin',
  ];
}

/// 지금 싸우는 보스가 특성 보스면 그 보스 (보스 특성 #25 — 처음 만날 때 옥토 한 마디).
BossDef? _traitBoss(GameState s, GameTables t) {
  final b = s.battle;
  if (b == null || !b.bossActive) return null;
  final kind = b.enemies.where((e) => e.boss).firstOrNull?.kind;
  final def = kind == null ? null : t.regions.bosses[kind];
  return def != null && def.traits.isNotEmpty ? def : null;
}

/// 특성 보스 한 마디 ('이 보스는 회피 25%! 투척·집속 선원이 잘 통해요.'). 특성 보스가 아니면 null.
String? bossTraitTalk(AppLocalizations l, WidgetRef ref) {
  final t = ref.watch(tablesProvider);
  final kind = ref.watch(gameStateProvider.select((s) => _traitBoss(s, t)?.id));
  final def = kind == null ? null : t.regions.bosses[kind];
  if (def == null) return null;
  final counters = def.counterFamilies.take(3).map((f) => tableText(l, t.skills.byId(f).nameKey)).join('·');
  return l.uiTalkBossTrait(def.traits.map((tr) => traitName(l, tr)).join(' · '), counters);
}

bool _rebirthReady(GameState s, GameTables t) {
  final r = rebirthPreview(s, t);
  return !r.locked && r.gain > 0;
}

/// 조건이 맞는 id들 — 쉼표로 이은 글(20Hz 상태에서 값이 같으면 다시 계산하지 않게).
final _activeProvider = Provider<String>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(gameStateProvider.select((s) => activeGuides(s, t).join(',')));
});

/// 처음 만나는 시스템 안내를 켤지 (테스트 하네스가 끈다 — 가이드를 시험하는 테스트만 켠다).
final guidesEnabledProvider = Provider<bool>((_) => true);

/// 지금 떠 있는 시스템 안내 id (튜토리얼 중엔 없음). 한 번에 하나, 줄 서기.
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
    bool wasSeen(String id) => seen.contains(id) || seen.contains(_legacyHints[id]);
    final cur = _current;
    // 전투 안내·상황 안내(보스 다시 도전)는 그 상황이 끝나면 닫힌다. 나머지는 닫을 때까지 남는다.
    if (cur != null && (!_situational.contains(cur) || active.contains(cur))) return cur;
    _current = guideIds.where((id) => active.contains(id) && !wasSeen(id) && !_shown.contains(id)).firstOrNull;
    if (_current case final id?) {
      _shown.add(id);
      // 띄우는 순간 본 것으로 남긴다(앱을 꺼도 다시 안 뜬다). 빌드 중 명령을 보내지 않게 한 박자 뒤.
      scheduleMicrotask(() => ref.read(commandSinkProvider).send(MarkHint(id)));
    }
    return _current;
  }

  /// 안내 닫기(톡·누를 곳을 누름).
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

  /// '안내를 끌까요? → 끄기': 남은 시스템 안내를 모두 본 것으로.
  void skipAll() {
    final sink = ref.read(commandSinkProvider);
    for (final id in guideIds) {
      if (_shown.add(id)) sink.send(MarkHint(id));
    }
    close();
  }
}

/// 상황이 끝나면 닫히는 안내.
const Set<String> _situational = {...battleGuideIds, 'guide.bossRetry'};

/// 한 마디의 내용. key가 바뀌면 새 말(0.7초 쉬고 나온다).
typedef GuideTalk = ({
  String key,
  String text,

  /// 밝게 하고 손가락을 얹을 곳(있는 것만).
  List<String> spots,

  /// 말풍선을 톡 누르면 넘어간다(튜토리얼 확인 단계·시스템 안내).
  bool ack,

  /// 밝은 곳 밖 누름을 막는다(튜토리얼 누를 곳 단계).
  bool block,

  /// 전투 중 — 어둡게·손가락 없이 말만, 접힌다.
  bool battle,

  /// 화면을 살짝 어둡게(첫 두 단계만).
  bool dim,
});

/// 화면 상태 (같은 단계 안에서 말을 고를 때): 시트 안 버튼이 보이는지, 파밍 중인지, 강화할 수 있는지.
typedef GuideScene = ({
  bool shipOpen,
  bool summonOpen,
  bool crewOpen,
  bool farming,
  bool canUpgrade,

  /// 특성 보스 한 마디([bossTraitTalk]) — 특성 보스가 아니면 null.
  String? bossTrait,
});

GuideTalk _t(
  String key,
  String text, {
  List<String> spots = const [],
  bool ack = false,
  bool block = false,
  bool dim = false,
}) => (key: key, text: text, spots: spots, ack: ack, block: block, battle: false, dim: dim);

/// 지금 할 말: 튜토리얼 단계([step]) 또는 시스템 안내([id]). 둘 다 없으면 null.
GuideTalk? guideTalkFor(AppLocalizations l, {required GuideScene scene, int? step, String? id}) {
  if (step != null) {
    return switch (step) {
      1 => _t('step.1', l.uiTalkWelcome, ack: true, dim: true),
      2 when scene.shipOpen => _t(
        'step.2.open',
        l.uiTalkUpgradeOpen,
        spots: ['ship.upgrade.cannon'],
        block: true,
        dim: true,
      ),
      2 => _t('step.2', l.uiTalkUpgrade, spots: ['quick.upgrade', 'tab.ship'], block: true, dim: true),
      3 when !scene.farming => _t('step.3.soon', l.uiTalkBossSoon),
      3 when scene.canUpgrade => _t('step.3.fail', l.uiTalkBossFail, spots: ['quick.upgrade'], block: true),
      3 => _t('step.3.go', l.uiTalkBossGo, spots: ['boss.challenge'], block: true),
      4 when scene.summonOpen => _t('step.4.ten', l.uiTalkSummonTen, spots: ['summon.ten'], block: true),
      4 => _t('step.4', l.uiTalkSummonTab, spots: ['tab.summon'], block: true),
      5 when scene.crewOpen => _t('step.5.all', l.uiTalkMergeAll, spots: ['crew.mergeAll'], block: true),
      5 => _t('step.5', l.uiTalkMergeTab, spots: ['tab.crew'], block: true),
      _ => _t('step.6', l.uiTalkDone, ack: true),
    };
  }
  if (id == null) return null;
  final text = switch (id) {
    'guide.sail' => l.uiTalkSail,
    'guide.boss' => l.uiTalkBoss,
    'guide.bossTrait' => scene.bossTrait ?? l.uiTalkBoss,
    'guide.collect' => l.uiTalkCollect,
    'guide.shipSkin' => l.uiTalkShipSkin,
    'guide.fever' => l.uiTalkFever,
    'guide.chest' => l.uiTalkChest,
    'guide.bossRetry' => l.uiTalkBossRetry,
    'guide.rebirth' => l.uiTalkRebirth,
    'guide.newCrew' => l.uiTalkNewCrew,
    'guide.cargo' => l.uiTalkCargo,
    'guide.merge' => l.uiTalkMerge,
    'guide.promote' => l.uiTalkPromote,
    _ => l.uiTalkSummon,
  };
  return (
    key: id,
    text: text,
    spots: guideSpots[id] ?? const [],
    ack: true,
    block: false,
    battle: battleGuideIds.contains(id),
    dim: false,
  );
}

/// 가이드 말 잠깐 멈춤 (환영 카드 순간 — S3 카드 연출이 전장 가운데에서 끝날 때까지, S3 c12ced0a).
final guideHoldProvider = NotifierProvider<GuideHold, bool>(GuideHold.new);

class GuideHold extends Notifier<bool> {
  Timer? _end;

  @override
  bool build() {
    ref.onDispose(() => _end?.cancel());
    return false;
  }

  /// 타이머를 멈춘다(접은 쪽 화면이 사라질 때 — 타이머가 남지 않게). 화면 정리 중이라 상태는 바꾸지 않는다.
  void release() {
    _end?.cancel();
    _end = null;
  }

  /// [duration] 동안 말을 접는다.
  void hold(Duration duration) {
    _end?.cancel();
    state = true;
    _end = Timer(duration, () => state = false);
  }
}

/// 지금 가리킬 수 있는 id들 (TutorialSpot이 자리를 등록한다 — 말에 따라 그중 보이는 것만 밝힌다). 튜토리얼 단계가 먼저.
final guidePointedProvider = Provider<Set<String>>((ref) {
  final step = ref.watch(tutorialStepProvider);
  if (step != null) return {...?tutorialSpots[step]};
  final id = ref.watch(guideQueueProvider);
  return {...?guideSpots[id]};
});
