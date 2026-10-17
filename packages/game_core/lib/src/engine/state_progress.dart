import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

// 세이브 조각: 진행·배 (state_parts.dart에서 나눔, 환생 v2 세이브 v6 필드 포함 — docs/specs/platform-rebirth-v2.md).

@immutable
class Progress {
  const Progress({
    this.stage = 1,
    this.wave = 0,
    this.bestStage = 1,
    this.farming = false,
    this.rebirths = 0,
    this.mapPiecesEarned = 0,
    this.titles = const [],
    this.treasureSea,
    this.treasureRoute,
    this.bossFails = 0,
    this.fever = 0,
    this.seaEventInSec,
    this.seaEventLast,
    this.challengeInSec,
    this.dex = const DexState(),
  });

  factory Progress.fromJson(Json j) => Progress(
    stage: j['stage'] as int,
    wave: j['wave'] as int,
    bestStage: j['bestStage'] as int,
    farming: j['farming'] as bool,
    rebirths: j['rebirths'] as int,
    mapPiecesEarned: j['mapPiecesEarned'] as int? ?? 0,
    titles: (j['titles'] as List?)?.cast<String>() ?? const [],
    treasureSea: j['treasureSea'] as int?,
    treasureRoute: j['treasureRoute'] as int?,
    bossFails: j['bossFails'] as int? ?? 0,
    fever: (j['fever'] as num?)?.toDouble() ?? 0,
    seaEventInSec: (j['seaEvents'] as Json?)?['inSec'] == null
        ? null
        : ((j['seaEvents'] as Json)['inSec'] as num).toDouble(),
    seaEventLast: (j['seaEvents'] as Json?)?['last'] as String?,
    challengeInSec: (j['challengeInSec'] as num?)?.toDouble(),
    dex: j['dex'] == null ? const DexState() : DexState.fromJson(j['dex'] as Json),
  );

  final int stage;

  /// 현재 스테이지에서 처치한 파 수 (0~wavesPerStage).
  final int wave;
  final int bestStage;

  /// 보스 실패 후 제자리 항해 중.
  final bool farming;
  final int rebirths;

  /// 모은 지도 조각 누계 (줄지 않음, 환생 보너스의 근거). 쓸 조각은 wallet.mapPieces (세이브 v6).
  final int mapPiecesEarned;

  /// 얻은 칭호 id (환생 횟수로 지급, 순서 = 얻은 순서).
  final List<String> titles;

  /// 이번 회차 보물 바다 해역 번호 (null = 보통 바다).
  final int? treasureSea;

  /// 다음 환생에 적용할 보물 바다 항로 (SetTreasureRoute, null = 끔).
  final int? treasureRoute;

  /// 보스 실패 누계 (UI ‘처음만 자세히’ 안내용, 세이브 v6 선택 키). 환생해도 유지.
  final int bossFails;

  /// 피버 게이지 0~1 (선택 키, 피버 진행 중은 저장하지 않는다 — platform-fun-fever).
  final double fever;

  /// 다음 돌발 이벤트까지 남은 초(없으면 다음 파부터 새로 뽑음)와 마지막 이벤트 id(연속 금지) — 선택 키 seaEvents.
  /// 전투 틱은 불러오면 0부터라 기획서의 nextAtTick 대신 남은 초로 저장한다.
  final double? seaEventInSec;
  final String? seaEventLast;

  /// 다음 즉석 도전까지 남은 초 (선택 키).
  final double? challengeInSec;

  /// 바다 괴물 도감: 만난 것·처치 수 (선택 키 dex, 환생해도 유지).
  final DexState dex;

  Progress copyWith({
    int? stage,
    int? wave,
    int? bestStage,
    bool? farming,
    int? rebirths,
    int? mapPiecesEarned,
    List<String>? titles,
    int? treasureSea,
    bool clearTreasureSea = false,
    int? treasureRoute,
    bool clearTreasureRoute = false,
    int? bossFails,
    double? fever,
    double? seaEventInSec,
    String? seaEventLast,
    double? challengeInSec,
    DexState? dex,
  }) => Progress(
    stage: stage ?? this.stage,
    wave: wave ?? this.wave,
    bestStage: bestStage ?? this.bestStage,
    farming: farming ?? this.farming,
    rebirths: rebirths ?? this.rebirths,
    mapPiecesEarned: mapPiecesEarned ?? this.mapPiecesEarned,
    titles: titles ?? this.titles,
    treasureSea: clearTreasureSea ? null : treasureSea ?? this.treasureSea,
    treasureRoute: clearTreasureRoute ? null : treasureRoute ?? this.treasureRoute,
    bossFails: bossFails ?? this.bossFails,
    fever: fever ?? this.fever,
    seaEventInSec: seaEventInSec ?? this.seaEventInSec,
    seaEventLast: seaEventLast ?? this.seaEventLast,
    challengeInSec: challengeInSec ?? this.challengeInSec,
    dex: dex ?? this.dex,
  );

  Json toJson() => {
    'stage': stage,
    'wave': wave,
    'bestStage': bestStage,
    'farming': farming,
    'rebirths': rebirths,
    'mapPiecesEarned': mapPiecesEarned,
    'titles': titles,
    'treasureSea': treasureSea,
    'treasureRoute': treasureRoute,
    'bossFails': bossFails,
    if (fever != 0) 'fever': fever,
    if (seaEventInSec != null || seaEventLast != null) 'seaEvents': {'inSec': seaEventInSec, 'last': seaEventLast},
    if (challengeInSec != null) 'challengeInSec': challengeInSec,
    if (!dex.isEmpty) 'dex': dex.toJson(),
  };
}

/// 바다 괴물 도감 (S1 2026-10-16 경제 계약, UI S4 apps/game/lib/ui/dex). id = 잡몹 kind 또는 보스 id.
@immutable
class DexState {
  const DexState({this.seen = const {}, this.kills = const {}});

  factory DexState.fromJson(Json j) => DexState(
    seen: {...(j['seen'] as List).cast<String>()},
    kills: (j['kills'] as Map).cast<String, int>(),
  );

  /// 만난 것(전장에 나타남) — 그림자로 보인다.
  final Set<String> seen;

  /// 처치 수 — 1 이상이면 모습 공개. 첫 처치(0 → 1)에 보상(meta.dex).
  final Map<String, int> kills;

  bool get isEmpty => seen.isEmpty && kills.isEmpty;
  int killsOf(String id) => kills[id] ?? 0;

  Json toJson() => {'seen': seen.toList()..sort(), 'kills': kills};
}

@immutable
class ShipState {
  const ShipState({
    this.parts = const {'cannon': 0, 'hull': 0, 'sail': 0, 'crowsnest': 0, 'cargo': 0},
    this.honorParts = const {},
    this.honorTier = 0,
    this.skin,
    this.skinsOwned = const {},
    this.skinChosen = false,
  });

  factory ShipState.fromJson(Json j) {
    final honor = j['honor'] as Json?;
    return ShipState(
      parts: (j['parts'] as Map).cast<String, int>(),
      honorParts: (honor?['parts'] as Map?)?.cast<String, int>() ?? const {},
      honorTier: honor?['tier'] as int? ?? 0,
      skin: j['skin'] as String?,
      skinsOwned: (j['skinsOwned'] as List?)?.cast<String>().toSet() ?? const {},
      skinChosen: j['skinChosen'] as bool? ?? false,
    );
  }

  /// 부위 id → 레벨.
  final Map<String, int> parts;

  /// 명예 외형: 부위 id → 지금까지 도달한 최고 외형 단계 (환생해도 유지, 그림만).
  final Map<String, int> honorParts;

  /// 도달한 최고 배 등급 순번 (ship_tiers.json 순서) — 배 그림만, 능력치는 지금 등급.
  final int honorTier;

  /// 장착한 환생 스킨 id (null = 기본 배).
  final String? skin;
  final Set<String> skinsOwned;

  /// 사용자가 스킨을 직접 고른 적이 있다 → 새 스킨을 얻어도 자동 장착하지 않는다.
  final bool skinChosen;

  int level(String part) => parts[part] ?? 0;

  ShipState withLevel(String part, int level) => copyWith(parts: {...parts, part: level});

  ShipState copyWith({
    Map<String, int>? parts,
    Map<String, int>? honorParts,
    int? honorTier,
    String? skin,
    bool clearSkin = false,
    Set<String>? skinsOwned,
    bool? skinChosen,
  }) => ShipState(
    parts: parts ?? this.parts,
    honorParts: honorParts ?? this.honorParts,
    honorTier: honorTier ?? this.honorTier,
    skin: clearSkin ? null : skin ?? this.skin,
    skinsOwned: skinsOwned ?? this.skinsOwned,
    skinChosen: skinChosen ?? this.skinChosen,
  );

  Json toJson() => {
    'parts': parts,
    'honor': {'parts': honorParts, 'tier': honorTier},
    'skin': skin,
    'skinsOwned': skinsOwned.toList()..sort(),
    'skinChosen': skinChosen,
  };
}
