import 'package:game_core/src/bignum/big_num.dart';
import 'package:meta/meta.dart';

export 'package:game_core/src/engine/state_bounty.dart';
export 'package:game_core/src/engine/state_dungeon.dart';
export 'package:game_core/src/engine/state_progress.dart';
export 'package:game_core/src/engine/state_rush.dart';
export 'package:game_core/src/engine/state_settings.dart';
export 'package:game_core/src/engine/state_tower.dart';

// 세이브 스키마 v1(docs/GAME_DESIGN.md 5.2)의 조각들. 모두 불변이고 JSON과 1:1.

typedef Json = Map<String, dynamic>;

@immutable
class Wallet {
  const Wallet({required this.gold, this.gems = 0, this.mapPieces = 0});

  factory Wallet.fromJson(Json j) => Wallet(
    gold: BigNum.parse(j['gold'] as String),
    gems: j['gems'] as int,
    mapPieces: j['mapPieces'] as int,
  );

  final BigNum gold;
  final int gems;

  /// 환생(보물지도) 조각.
  final int mapPieces;

  Wallet copyWith({BigNum? gold, int? gems, int? mapPieces}) =>
      Wallet(gold: gold ?? this.gold, gems: gems ?? this.gems, mapPieces: mapPieces ?? this.mapPieces);

  Json toJson() => {'gold': gold.toJson(), 'gems': gems, 'mapPieces': mapPieces};
}

@immutable
class CrewState {
  const CrewState({this.level = 1, this.exp = 0, this.cards = 0});

  factory CrewState.fromJson(Json j) =>
      CrewState(level: j['level'] as int, exp: j['exp'] as int, cards: j['cards'] as int);

  /// 1~75. 등급은 레벨 구간으로 정해진다(rarities.json).
  final int level;
  final int exp;

  /// 아직 합치지 않은 카드 수.
  final int cards;

  CrewState copyWith({int? level, int? exp, int? cards}) =>
      CrewState(level: level ?? this.level, exp: exp ?? this.exp, cards: cards ?? this.cards);

  Json toJson() => {'level': level, 'exp': exp, 'cards': cards};
}

@immutable
class Buffs {
  const Buffs({this.tailwindUntil, this.bossSupportUntil, this.autoUpgradeUntil});

  factory Buffs.fromJson(Json j) => Buffs(
    tailwindUntil: parseTime(j['tailwindUntil']),
    bossSupportUntil: parseTime(j['bossSupportUntil']),
    autoUpgradeUntil: parseTime(j['autoUpgradeUntil']),
  );

  /// 순풍 버프 종료 시각(UTC): 골드·전투 속도 (ads.json tailwind).
  final DateTime? tailwindUntil;

  /// 함포 지원 종료 시각(UTC): 보스 재도전 피해 + (ads.json bossSupport). 세이브에 없어도 된다(선택 키).
  final DateTime? bossSupportUntil;

  /// 자동 강화 종료 시각(UTC): 보상형 광고로만 켜진다(사용자 결정 2026-10-16 — 평소엔 수동 강화만). 선택 키.
  final DateTime? autoUpgradeUntil;

  Buffs copyWith({
    DateTime? tailwindUntil,
    DateTime? bossSupportUntil,
    DateTime? autoUpgradeUntil,
    bool clearAutoUpgrade = false,
  }) => Buffs(
    tailwindUntil: tailwindUntil ?? this.tailwindUntil,
    bossSupportUntil: bossSupportUntil ?? this.bossSupportUntil,
    autoUpgradeUntil: clearAutoUpgrade ? null : autoUpgradeUntil ?? this.autoUpgradeUntil,
  );

  Json toJson() => {
    'tailwindUntil': tailwindUntil?.toUtc().toIso8601String(),
    if (bossSupportUntil != null) 'bossSupportUntil': bossSupportUntil!.toUtc().toIso8601String(),
    if (autoUpgradeUntil != null) 'autoUpgradeUntil': autoUpgradeUntil!.toUtc().toIso8601String(),
  };
}

@immutable
class DailyState {
  const DailyState({
    required this.date,
    this.ads = const {},
    this.quests = const {},
    this.attendanceDay = 0,
    this.questsClaimed = const {},
    this.attendanceClaimed = false,
  });

  factory DailyState.fromJson(Json j) => DailyState(
    date: j['date'] as String,
    ads: (j['ads'] as Map).cast<String, int>(),
    quests: (j['quests'] as Map).cast<String, int>(),
    attendanceDay: j['attendanceDay'] as int,
    questsClaimed: (j['questsClaimed'] as List).cast<String>().toSet(),
    attendanceClaimed: j['attendanceClaimed'] as bool,
  );

  /// 기기 현지 날짜 `yyyy-mm-dd`. 바뀌면 일일 값 초기화.
  final String date;

  /// 광고 장치 id → 오늘 본 횟수.
  final Map<String, int> ads;

  /// 일일 퀘스트 id → 진행도.
  final Map<String, int> quests;

  /// 출석 1~7. 빠져도 초기화하지 않는다.
  final int attendanceDay;

  /// 오늘 보상을 받은 일일 퀘스트 id (세이브 v3).
  final Set<String> questsClaimed;

  /// 오늘 출석 보상을 받았다 (세이브 v3).
  final bool attendanceClaimed;

  DailyState copyWith({
    String? date,
    Map<String, int>? ads,
    Map<String, int>? quests,
    int? attendanceDay,
    Set<String>? questsClaimed,
    bool? attendanceClaimed,
  }) => DailyState(
    date: date ?? this.date,
    ads: ads ?? this.ads,
    quests: quests ?? this.quests,
    attendanceDay: attendanceDay ?? this.attendanceDay,
    questsClaimed: questsClaimed ?? this.questsClaimed,
    attendanceClaimed: attendanceClaimed ?? this.attendanceClaimed,
  );

  Json toJson() => {
    'date': date,
    'ads': ads,
    'quests': quests,
    'attendanceDay': attendanceDay,
    'questsClaimed': (questsClaimed.toList()..sort()),
    'attendanceClaimed': attendanceClaimed,
  };
}

DateTime? parseTime(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();

/// 소환 1장의 결과 (설계서 4.3 소환 연출).
@immutable
class SummonResult {
  const SummonResult({required this.crewId, required this.rarity, this.isNew = false});

  final String crewId;

  /// 카드 등급 id (rarities.json).
  final String rarity;

  /// 처음 얻은 선원(도감 새로 등록).
  final bool isNew;
}
