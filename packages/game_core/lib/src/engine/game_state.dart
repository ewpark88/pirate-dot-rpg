import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
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
    this.tokens = 0,
    this.pityCount = 0,
    this.buffs = const Buffs(),
    this.collection = const {},
    this.settings = const Settings(),
    this.operator = false,
    this.battle,
  });

  /// 새 게임. [now]는 Clock에서, [seed]는 플랫폼 난수에서 받는다.
  factory GameState.newGame({required String playerId, required int seed, required DateTime now}) => GameState(
    playerId: playerId,
    rngSeed: seed,
    savedAt: now.toUtc(),
    wallet: const Wallet(gold: BigNum.zero),
    daily: DailyState(date: localDate(now)),
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
    tokens: j['tokens'] as int,
    pityCount: (j['summon'] as Json)['pityCount'] as int,
    buffs: Buffs.fromJson(j['buffs'] as Json),
    daily: DailyState.fromJson(j['daily'] as Json),
    collection: (j['collection'] as List).cast<String>().toSet(),
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

  /// 해적의 증표.
  final int tokens;

  /// 영웅 이상이 안 나온 연속 소환 수 (천장).
  final int pityCount;
  final Buffs buffs;
  final DailyState daily;

  /// 도감에 등록된 선원 id.
  final Set<String> collection;
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
    int? tokens,
    int? pityCount,
    Buffs? buffs,
    DailyState? daily,
    Set<String>? collection,
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
    tokens: tokens ?? this.tokens,
    pityCount: pityCount ?? this.pityCount,
    buffs: buffs ?? this.buffs,
    daily: daily ?? this.daily,
    collection: collection ?? this.collection,
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
    'tokens': tokens,
    'summon': {'pityCount': pityCount},
    'buffs': buffs.toJson(),
    'daily': daily.toJson(),
    'collection': collection.toList()..sort(),
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
