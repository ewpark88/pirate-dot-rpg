import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 설정(세이브 settings) — state_parts.dart 300줄이라 나눔(boss-feel 2026-10-17). state_parts가 다시 내보낸다.

@immutable
class Settings {
  const Settings({
    this.lang = 'system',
    this.autoUpgrade = true,
    this.autoBoss = true,
    this.autoUltimate = true,
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
    autoUltimate: j['autoUltimate'] as bool? ?? true,
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

  /// 선장 필살기 자동 사용(boss-feel, 기본 켬 — 방치형). 끄면 게이지가 차도 버튼(TriggerUltimate)을 눌러야 쓴다. 선택 키.
  final bool autoUltimate;
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
    if (!autoUltimate) 'autoUltimate': false,
  };

  /// [withValue]용: 생략된 선택 키까지 모두 채운 본문.
  Json _full() => {
    ...toJson(),
    'battleView': battleView,
    'flashLevel': flashLevel,
    'sleepAfterSec': sleepAfterSec,
    'autoUltimate': autoUltimate,
  };

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
