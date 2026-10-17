import 'package:game_core/src/bignum/big_num.dart';
import 'package:meta/meta.dart';

export 'package:game_core/src/engine/state_achievements.dart';
export 'package:game_core/src/engine/state_bounty.dart';
export 'package:game_core/src/engine/state_dungeon.dart';
export 'package:game_core/src/engine/state_progress.dart';
export 'package:game_core/src/engine/state_rush.dart';
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

@immutable
class Settings {
  const Settings({
    this.lang = 'system',
    this.autoUpgrade = true,
    this.autoBoss = true,
    this.powerSave = true,
    this.bgm = true,
    this.sfx = true,
    this.vibration = true,
    this.shake = true,
    this.flash = true,
    this.notifications = true,
    this.battleView = 'top',
    this.title,
    this.hints = const {},
    String? flashLevel,
    this.sleepAfterSec = defaultSleepAfterSec,
  }) : flashLevel = flashLevel ?? (flash ? 'soft' : 'off');

  factory Settings.fromJson(Json j) => Settings(
    lang: j['lang'] as String,
    autoUpgrade: j['autoUpgrade'] as bool,
    autoBoss: j['autoBoss'] as bool,
    powerSave: j['powerSave'] as bool,
    bgm: j['bgm'] as bool,
    sfx: j['sfx'] as bool,
    vibration: j['vibration'] as bool,
    shake: j['shake'] as bool,
    flash: j['flash'] as bool,
    notifications: j['notifications'] as bool,
    battleView: j['battleView'] as String? ?? 'top',
    title: j['title'] as String?,
    hints: {...?(j['hints'] as List?)?.cast<String>()},
    flashLevel: j['flashLevel'] as String?,
    sleepAfterSec: j['sleepAfterSec'] as int? ?? defaultSleepAfterSec,
  );

  /// 자동 절전 화면 기본(초) — S4 '발열·배터리·OLED'.
  static const defaultSleepAfterSec = 600;

  /// `system` | `ko` | `en`.
  final String lang;
  final bool autoUpgrade;
  final bool autoBoss;
  final bool powerSave;
  final bool bgm;
  final bool sfx;
  final bool vibration;
  final bool shake;
  final bool flash;

  /// 오프라인 보상 가득 로컬 알림 (platform, 하루 최대 `meta.notifications.dailyMax`). 기본 켜짐 — 세이브 v4.
  final bool notifications;

  /// 전투 화면 방식 `side`(옆모습) | `top`(탑다운) — 탑다운 전환 T0 (docs/plans/active/topdown-migration.md).
  /// 세이브 선택 키(없으면 top — T4 전환 2026-10-15, 옛 세이브도 탑다운). side는 옆모습 코드 삭제 전까지만 남는다.
  final String battleView;

  /// 고른 칭호 id (progress.titles 중, null = 없음 — 세이브 v6).
  final String? title;

  /// 번쩍임 세기 `off` | `soft` | `full` (사용자 '번쩍임 눈 아프다'). 선택 키, 없으면 [flash]에서(켬 → soft, 끔 → off).
  /// [flash]는 옛 세이브·화면용으로 남고 `flashLevel != 'off'`와 같다.
  final String flashLevel;

  /// 입력이 없을 때 절전 화면까지 초(0 = 끔, 60·180·300). 선택 키, 없으면 [defaultSleepAfterSec]. 감지·덮개는 UI.
  final int sleepAfterSec;

  /// 한 번 본 안내(말풍선) id — 다시 띄우지 않는다(S4 '처음 1회 안내'). 선택 키, 없으면 빈 집합.
  final Set<String> hints;

  Json toJson() => {
    'lang': lang,
    'autoUpgrade': autoUpgrade,
    'autoBoss': autoBoss,
    'powerSave': powerSave,
    'bgm': bgm,
    'sfx': sfx,
    'vibration': vibration,
    'shake': shake,
    'flash': flash,
    'notifications': notifications,
    // 옆모습(기본)은 쓰지 않는다 — 옛 픽스처·세이브와 같은 본문.
    if (battleView != 'top') 'battleView': battleView,
    if (title != null) 'title': title,
    if (hints.isNotEmpty) 'hints': (hints.toList()..sort()),
    if (flashLevel != (flash ? 'soft' : 'off')) 'flashLevel': flashLevel,
    if (sleepAfterSec != defaultSleepAfterSec) 'sleepAfterSec': sleepAfterSec,
  };

  /// [withValue]용: 생략된 선택 키까지 모두 채운 본문.
  Json _full() => {...toJson(), 'battleView': battleView, 'flashLevel': flashLevel, 'sleepAfterSec': sleepAfterSec};

  /// 칭호만 바꾼다 (SelectTitle, null = 없음).
  Settings withHint(String id) => Settings.fromJson({
    ..._full(),
    'hints': [...hints, id],
  });

  /// [prefix]로 시작하는 안내 id를 지운다 (ClearHints, 빈 prefix = 전부).
  Settings withoutHints(String prefix) => Settings.fromJson({
    ..._full(),
    'hints': [
      for (final h in hints)
        if (!h.startsWith(prefix)) h,
    ],
  });

  Settings withTitle(String? id) => Settings.fromJson({..._full(), 'title': id});

  /// 키 하나만 바꾼다 (SetSetting 명령용). 모르는 키는 [ArgumentError].
  Settings withValue(String key, Object value) {
    final j = _full();
    if (!j.containsKey(key) || j[key].runtimeType != value.runtimeType) {
      throw ArgumentError('설정 키/타입 오류: $key=$value');
    }
    if (key == 'flashLevel' && !const {'off', 'soft', 'full'}.contains(value)) {
      throw ArgumentError('설정 값 오류: $key=$value');
    }
    if (key == 'sleepAfterSec' && (value as int) < 0) throw ArgumentError('설정 값 오류: $key=$value');
    // 번쩍임 둘은 함께 움직인다: 끔/켬 → 세기(켬은 soft), 세기 → 끔/켬.
    if (key == 'flash') return Settings.fromJson({...j, 'flash': value, 'flashLevel': value == true ? 'soft' : 'off'});
    if (key == 'flashLevel') return Settings.fromJson({...j, 'flashLevel': value, 'flash': value != 'off'});
    return Settings.fromJson({...j, key: value});
  }
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
