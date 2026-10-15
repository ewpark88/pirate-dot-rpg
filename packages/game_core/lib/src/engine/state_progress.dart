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
    this.rage = 0,
    this.mapPiecesEarned = 0,
    this.titles = const [],
    this.treasureSea,
    this.treasureRoute,
    this.bossFails = 0,
  });

  factory Progress.fromJson(Json j) => Progress(
    stage: j['stage'] as int,
    wave: j['wave'] as int,
    bestStage: j['bestStage'] as int,
    farming: j['farming'] as bool,
    rebirths: j['rebirths'] as int,
    rage: (j['rage'] as num).toDouble(),
    mapPiecesEarned: j['mapPiecesEarned'] as int? ?? 0,
    titles: (j['titles'] as List?)?.cast<String>() ?? const [],
    treasureSea: j['treasureSea'] as int?,
    treasureRoute: j['treasureRoute'] as int?,
    bossFails: j['bossFails'] as int? ?? 0,
  );

  final int stage;

  /// 현재 스테이지에서 처치한 파 수 (0~wavesPerStage).
  final int wave;
  final int bestStage;

  /// 보스 실패 후 제자리 항해 중.
  final bool farming;
  final int rebirths;

  /// 함성 게이지 0~1.
  final double rage;

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

  Progress copyWith({
    int? stage,
    int? wave,
    int? bestStage,
    bool? farming,
    int? rebirths,
    double? rage,
    int? mapPiecesEarned,
    List<String>? titles,
    int? treasureSea,
    bool clearTreasureSea = false,
    int? treasureRoute,
    bool clearTreasureRoute = false,
    int? bossFails,
  }) => Progress(
    stage: stage ?? this.stage,
    wave: wave ?? this.wave,
    bestStage: bestStage ?? this.bestStage,
    farming: farming ?? this.farming,
    rebirths: rebirths ?? this.rebirths,
    rage: rage ?? this.rage,
    mapPiecesEarned: mapPiecesEarned ?? this.mapPiecesEarned,
    titles: titles ?? this.titles,
    treasureSea: clearTreasureSea ? null : treasureSea ?? this.treasureSea,
    treasureRoute: clearTreasureRoute ? null : treasureRoute ?? this.treasureRoute,
    bossFails: bossFails ?? this.bossFails,
  );

  Json toJson() => {
    'stage': stage,
    'wave': wave,
    'bestStage': bestStage,
    'farming': farming,
    'rebirths': rebirths,
    'rage': rage,
    'mapPiecesEarned': mapPiecesEarned,
    'titles': titles,
    'treasureSea': treasureSea,
    'treasureRoute': treasureRoute,
    'bossFails': bossFails,
  };
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
