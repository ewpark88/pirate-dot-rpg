import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/state_iap.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

/// 게임 전체 상태의 불변 스냅샷. UI·렌더는 이것을 구독만 한다.
///
/// [battle]을 뺀 나머지가 세이브 스키마 v1(docs/GAME_DESIGN.md 5.2)과 1:1이다.
@immutable
class GameState {
  const GameState({
    required this.playerId,
    required this.rngSeed,
    required this.savedAt,
    required this.wallet,
    required this.daily,
    this.progress = const Progress(),
    this.ship = const ShipState(),
    this.crews = const {},
    this.fleet = const [],
    this.fleetInit = false,
    this.rebirthShop = const {},
    this.bounty,
    this.tower,
    this.rush,
    this.tokens = 0,
    this.pityCount = 0,
    this.summonsTotal = 0,
    this.tutorialStep,
    this.lastSummon,
    this.lastOfflineGold,
    this.buffs = const Buffs(),
    this.collection = const {},
    this.entitlements = const {},
    this.purchaseTokens = const [],
    this.pass,
    this.settings = const Settings(),
    this.operator = false,
    this.battle,
  });

  /// 새 게임. [now]는 Clock에서, [seed]는 플랫폼 난수에서 받는다.
  /// [crews]는 시작 선원 (`tables.meta.startingCrews`, 설계서 4.3.3) — 레벨 1로 보유·도감 등록.
  factory GameState.newGame({
    required String playerId,
    required int seed,
    required DateTime now,
    Iterable<String> crews = const [],
  }) => GameState(
    playerId: playerId,
    rngSeed: seed,
    savedAt: now.toUtc(),
    wallet: const Wallet(gold: BigNum.zero),
    daily: DailyState(date: localDate(now)),
    crews: {for (final id in crews) id: const CrewState()},
    collection: crews.toSet(),
    tutorialStep: 1,
  );

  /// 세이브 본문(체크섬·schemaVersion 제외)에서 만든다. 형식 오류는 TypeError/FormatException.
  factory GameState.fromJson(Json j) => GameState(
    playerId: j['playerId'] as String,
    rngSeed: j['rngSeed'] as int,
    savedAt: parseTime(j['savedAt'])!,
    operator: j['operator'] as bool? ?? false,
    wallet: Wallet.fromJson(j['wallet'] as Json),
    progress: Progress.fromJson(j['progress'] as Json),
    ship: ShipState.fromJson(j['ship'] as Json),
    crews: {
      for (final e in (j['crews'] as Json).entries) e.key: CrewState.fromJson(e.value as Json),
    },
    // v5 키. 마이그레이션을 거치지 않는 상태 픽스처(fixtures/states)에는 없을 수 있다 → ‘편성 전’.
    fleet: (j['fleet'] as List?)?.cast<String?>() ?? const [],
    fleetInit: j['fleetInit'] as bool? ?? false,
    rebirthShop: (j['rebirthShop'] as Map?)?.cast<String, int>() ?? const {},
    bounty: j['bounty'] == null ? null : BountyState.fromJson(j['bounty'] as Json),
    tower: j['tower'] == null ? null : TowerState.fromJson(j['tower'] as Json),
    rush: j['rush'] == null ? null : RushState.fromJson(j['rush'] as Json),
    tokens: j['tokens'] as int,
    pityCount: (j['summon'] as Json)['pityCount'] as int,
    summonsTotal: (j['summon'] as Json)['total'] as int,
    tutorialStep: j['tutorialStep'] as int?,
    buffs: Buffs.fromJson(j['buffs'] as Json),
    daily: DailyState.fromJson(j['daily'] as Json),
    collection: (j['collection'] as List).cast<String>().toSet(),
    entitlements: {
      for (final e in ((j['entitlements'] as Json?) ?? const {}).entries) e.key: Entitlement.fromJson(e.value as Json),
    },
    purchaseTokens: (j['purchaseTokens'] as List?)?.cast<String>() ?? const [],
    pass: j['pass'] == null ? null : PassState.fromJson(j['pass'] as Json),
    settings: Settings.fromJson(j['settings'] as Json),
    battle: j['battle'] == null ? null : BattleView.fromJson(j['battle'] as Json),
  );

  final String playerId;

  /// 현재 난수 상태. 불러오면 여기서 이어서 굴린다.
  final int rngSeed;
  final DateTime savedAt;
  final Wallet wallet;
  final Progress progress;
  final ShipState ship;

  /// 보유 선원 id → 상태. 없는 선원은 미보유.
  final Map<String, CrewState> crews;

  /// 출전 편성 (세이브 v5, ADR-0010): 슬롯 순서대로 선원 id, null은 빈 칸. 배 등급 슬롯 수보다 길면
  /// 앞 칸만 출전한다(환생으로 슬롯이 줄어도 뒤 칸 기록은 남김). 편성 판정은 `activeFleet`.
  final List<String?> fleet;

  /// 한 번이라도 편성됐는가. false면(새 게임·v4 이전 세이브) 경제가 첫 틱에 자동 편성으로 채운다.
  final bool fleetInit;

  /// 보물지도 상점: 항목 id → 레벨 (환생해도 유지, 세이브 v6).
  final Map<String, int> rebirthShop;

  /// 현상금 사냥 (docs/specs/platform-content-bounty.md 4절, 세이브 v6 키 그대로). null = 아직 없음(경제가 첫 틱에 채운다).
  final BountyState? bounty;

  /// 심연의 탑(platform-content-v2 4절, 선택 키). null = 아직 없음(열리면 경제가 채운다).
  final TowerState? tower;

  /// 보스 러시(platform-boss-rush, 선택 키). null = 아직 없음.
  final RushState? rush;

  /// 해적의 증표.
  final int tokens;

  /// 영웅 이상이 안 나온 연속 소환 수 (천장).
  final int pityCount;

  /// 누적 소환 횟수. 0이면 첫 10연 무료(설계서 4.12, 세이브 v2).
  final int summonsTotal;

  /// 튜토리얼 단계(설계서 4.12, 1부터). null이면 끝냈거나 건너뜀 (세이브 v3).
  final int? tutorialStep;

  /// 방금 소환한 결과 (소환 결과 연출용, 세이브 밖). 화면이 닫으면 AckSummonResult로 지운다.
  final List<SummonResult>? lastSummon;

  /// 이번 복귀에 받은 오프라인 골드 (광고 ×2 '복귀당 1회'용, 세이브 밖). 광고로 두 배를 받으면 경제가 지운다.
  final BigNum? lastOfflineGold;
  final Buffs buffs;
  final DailyState daily;

  /// 도감에 등록된 선원 id.
  final Set<String> collection;

  /// 유료 권리(계약 platform-iap, 선택 키): 권리 id(noAds·speed·gemSub·offline12·pass) 또는 `product:<id>`(산 기록) → 기간.
  final Map<String, Entitlement> entitlements;

  /// 지급한 영수증 토큰(최근 [purchaseTokenKeep]개) — 같은 토큰이 다시 오면 지급하지 않는다.
  final List<String> purchaseTokens;

  /// 항해 패스 진행(선택 키, 무료 줄은 누구나). null = 아직 시작 전(첫 틱에 만든다).
  final PassState? pass;
  final Settings settings;

  /// 운영자 모드로 바뀐 적이 있는 세이브. 랭킹에 제출하지 않는다.
  final bool operator;

  /// 전장 스냅샷. 저장하지 않는다(null이면 아직 전투 시작 전).
  final BattleView? battle;

  GameState copyWith({
    int? rngSeed,
    DateTime? savedAt,
    Wallet? wallet,
    Progress? progress,
    ShipState? ship,
    Map<String, CrewState>? crews,
    List<String?>? fleet,
    bool? fleetInit,
    Map<String, int>? rebirthShop,
    BountyState? bounty,
    TowerState? tower,
    RushState? rush,
    int? tokens,
    int? pityCount,
    int? summonsTotal,
    int? tutorialStep,
    bool clearTutorial = false,
    List<SummonResult>? lastSummon,
    bool clearLastSummon = false,
    BigNum? lastOfflineGold,
    bool clearLastOfflineGold = false,
    Buffs? buffs,
    DailyState? daily,
    Set<String>? collection,
    Map<String, Entitlement>? entitlements,
    List<String>? purchaseTokens,
    PassState? pass,
    Settings? settings,
    bool? operator,
    BattleView? battle,
  }) => GameState(
    playerId: playerId,
    rngSeed: rngSeed ?? this.rngSeed,
    savedAt: savedAt ?? this.savedAt,
    wallet: wallet ?? this.wallet,
    progress: progress ?? this.progress,
    ship: ship ?? this.ship,
    crews: crews ?? this.crews,
    fleet: fleet ?? this.fleet,
    fleetInit: fleetInit ?? this.fleetInit,
    rebirthShop: rebirthShop ?? this.rebirthShop,
    bounty: bounty ?? this.bounty,
    tower: tower ?? this.tower,
    rush: rush ?? this.rush,
    tokens: tokens ?? this.tokens,
    pityCount: pityCount ?? this.pityCount,
    summonsTotal: summonsTotal ?? this.summonsTotal,
    tutorialStep: clearTutorial ? null : tutorialStep ?? this.tutorialStep,
    lastSummon: clearLastSummon ? null : lastSummon ?? this.lastSummon,
    lastOfflineGold: clearLastOfflineGold ? null : lastOfflineGold ?? this.lastOfflineGold,
    buffs: buffs ?? this.buffs,
    daily: daily ?? this.daily,
    collection: collection ?? this.collection,
    entitlements: entitlements ?? this.entitlements,
    purchaseTokens: purchaseTokens ?? this.purchaseTokens,
    pass: pass ?? this.pass,
    settings: settings ?? this.settings,
    operator: operator ?? this.operator,
    battle: battle ?? this.battle,
  );

  /// 세이브 본문. [includeBattle]은 픽스처(fixtures/states) 용도로만 쓴다.
  Json toJson({bool includeBattle = false}) => {
    'savedAt': savedAt.toUtc().toIso8601String(),
    'playerId': playerId,
    'rngSeed': rngSeed,
    'operator': operator,
    'wallet': wallet.toJson(),
    'progress': progress.toJson(),
    'ship': ship.toJson(),
    'crews': {for (final e in crews.entries) e.key: e.value.toJson()},
    'fleet': fleet,
    'fleetInit': fleetInit,
    'rebirthShop': rebirthShop,
    'bounty': bounty?.toJson(),
    if (tower != null) 'tower': tower!.toJson(),
    if (rush != null) 'rush': rush!.toJson(),
    'tokens': tokens,
    'summon': {'pityCount': pityCount, 'total': summonsTotal},
    'tutorialStep': tutorialStep,
    'buffs': buffs.toJson(),
    'daily': daily.toJson(),
    'collection': collection.toList()..sort(),
    if (entitlements.isNotEmpty) 'entitlements': {for (final e in entitlements.entries) e.key: e.value.toJson()},
    if (purchaseTokens.isNotEmpty) 'purchaseTokens': purchaseTokens,
    if (pass != null) 'pass': pass!.toJson(),
    'settings': settings.toJson(),
    if (includeBattle && battle != null) 'battle': battle!.toJson(),
  };
}

/// 기기 현지 날짜 `yyyy-mm-dd` (일일 초기화 기준).
String localDate(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// 기억하는 영수증 토큰 수(오래된 것부터 버린다 — 스토어가 같은 구매를 다시 보내는 건 며칠 안).
const purchaseTokenKeep = 200;
