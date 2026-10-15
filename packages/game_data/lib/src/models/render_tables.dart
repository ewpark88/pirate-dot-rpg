import 'package:game_data/src/models/common.dart';

/// `#RRGGBB` → 불투명 ARGB 정수 (dart:ui 없이 색을 넘긴다).
int parseArgb(String hex, String path) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (m == null) throw TableFormatException(path, '#RRGGBB 색이어야 하는데 $hex');
  return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

/// 흔들림 한 종류: 진폭(px)과 길이(ms).
class ShakeSpec {
  ShakeSpec.fromJson(JsonReader j) : px = j.number('px'), ms = j.number('ms');

  final double px;
  final double ms;
}

/// 데미지 숫자 모양 (일반/치명/범위 합산).
class DamageNumberSpec {
  DamageNumberSpec.fromJson(JsonReader j)
    : normalScale = j.number('normalScale'),
      critScale = j.number('critScale'),
      normalColor = parseArgb(j.str('normalColor'), '${j.path}.normalColor'),
      critColor = parseArgb(j.str('critColor'), '${j.path}.critColor'),
      sumColor = parseArgb(j.str('sumColor'), '${j.path}.sumColor'),
      lifeMs = j.number('lifeMs'),
      risePx = j.number('risePx'),
      critBouncePx = j.number('critBouncePx');

  final double normalScale;
  final double critScale;
  final int normalColor;
  final int critColor;
  final int sumColor;
  final double lifeMs;
  final double risePx;
  final double critBouncePx;
}

/// 타격감 수치(juice.json). 렌더 레인이 읽고, 운영자 모드에서 슬라이더로 조절한다.
class JuiceTable {
  JuiceTable.fromJson(this.raw)
    : maxEffects = raw.obj('limits').integer('effects'),
      maxDamageNumbers = raw.obj('limits').integer('damageNumbers'),
      maxProjectiles = raw.obj('limits').integer('projectiles'),
      maxCoins = raw.obj('limits').integer('coins'),
      hitStopMs = raw.numberMap('hitStopMs'),
      shake = {for (final k in raw.obj('shake').raw.keys) k: ShakeSpec.fromJson(raw.obj('shake').obj(k))},
      flashFrames = raw.integer('flashFrames'),
      knockbackPx = raw.numberMap('knockbackPx'),
      knockbackMs = raw.number('knockbackMs'),
      damageNumber = DamageNumberSpec.fromJson(raw.obj('damageNumber')),
      bossSlowMoMs = raw.obj('bossKill').number('slowMoMs'),
      bossSlowMoRate = raw.obj('bossKill').number('slowMoRate'),
      bossFlash = raw.obj('bossKill').boolean('flash'),
      bossCoinRain = raw.obj('bossKill').integer('coinRain'),
      coinCount = raw.obj('kill').integer('coinCount'),
      coinFlyMs = raw.obj('kill').number('coinFlyMs'),
      lookaheadTicks = raw.obj('replay').integer('lookaheadTicks'),
      liveMaxLagTicks = raw.obj('replay').integer('liveMaxLagTicks'),
      powerSaveFps = raw.obj('powerSave').integer('fps');

  final JsonReader raw;
  final int maxEffects;
  final int maxDamageNumbers;
  final int maxProjectiles;
  final int maxCoins;
  final Map<String, double> hitStopMs;
  final Map<String, ShakeSpec> shake;
  final int flashFrames;
  final Map<String, double> knockbackPx;
  final double knockbackMs;
  final DamageNumberSpec damageNumber;
  final double bossSlowMoMs;
  final double bossSlowMoRate;
  final bool bossFlash;

  /// 보스 처치 때 화면 위에서 떨어지는 코인 수.
  final int bossCoinRain;
  final int coinCount;
  final double coinFlyMs;

  /// 표시 시각을 최신 틱보다 늦추는 틱 수 (발사체 비행 연출용).
  final int lookaheadTicks;

  /// 라이브 재생에서 lookahead보다 더 뒤처져도 되는 틱 수 (넘으면 따라잡는다).
  final int liveMaxLagTicks;
  final int powerSaveFps;

  List<String> validate() {
    final e = <String>[];
    expect(e, that: maxEffects > 0 && maxEffects <= 64, message: 'juice: limits.effects는 1~64');
    expect(e, that: maxDamageNumbers > 1, message: 'juice: limits.damageNumbers > 1 (넘치면 둘을 합친다)');
    expect(e, that: maxProjectiles > 0 && maxCoins > 0, message: 'juice: limits.projectiles·coins > 0');
    for (final k in ['aoe', 'ultimate', 'bossKill']) {
      expect(e, that: shake.containsKey(k), message: 'juice: shake.$k 없음');
    }
    expect(e, that: lookaheadTicks >= 1, message: 'juice: replay.lookaheadTicks >= 1');
    expect(e, that: bossSlowMoRate > 0 && bossSlowMoRate <= 1, message: 'juice: bossKill.slowMoRate는 0~1');
    return e;
  }
}

class FxSheetDef {
  FxSheetDef.fromJson(JsonReader j)
    : id = j.str('id'),
      w = j.integer('w'),
      h = j.integer('h'),
      frames = j.integer('frames');

  final String id;
  final int w;
  final int h;
  final int frames;
}

/// 발사체 비행 모양.
enum ProjectilePath { line, arc, skip, drop }

/// 계열 하나의 발사체 모양 (fx_map.json projectiles).
class ProjectileStyle {
  ProjectileStyle.fromJson(JsonReader j)
    : color = parseArgb(j.str('color'), '${j.path}.color'),
      size = j.number('size'),
      path = ProjectilePath.values.byName(j.str('path')),
      arcPx = j.numberOr('arcPx', 0),
      burst = j.intOrNull('burst') ?? 1,
      burstGapMs = j.numberOr('burstGapMs', 0);

  final int color;
  final double size;
  final ProjectilePath path;

  /// 포물선·낙하 높이(px).
  final double arcPx;

  /// 한 대상에 쏘는 연사 수와 간격.
  final int burst;
  final double burstGapMs;
}

/// 궁극기 화면 연출 패턴 (fx_map.json ultimates).
enum UltimatePatternKind { sweep, rain, strikes, volley }

class UltimatePattern {
  UltimatePattern.fromJson(JsonReader j)
    : kind = UltimatePatternKind.values.byName(j.str('pattern')),
      fx = j.str('fx'),
      count = j.integer('count'),
      durationMs = j.number('durationMs'),
      raw = j;

  final UltimatePatternKind kind;
  final String fx;
  final int count;
  final double durationMs;

  /// sweep 선택값: 크기 배율·높이(중심 y)·시작·끝 중심 x (`numberOr`로 읽는다).
  final JsonReader raw;
}

/// 적 역할별 플레이스홀더 모양 (fx_map.json enemyLook).
class EnemyLook {
  EnemyLook.fromJson(JsonReader j)
    : color = parseArgb(j.str('color'), '${j.path}.color'),
      size = j.number('size'),
      alpha = j.number('alpha');

  final int color;
  final double size;
  final double alpha;
}

/// 게임 이벤트 → 이펙트·효과음 (fx_map.json).
class FxMapTable {
  FxMapTable.fromJson(JsonReader j)
    : raw = j,
      events = {
        for (final k in j.obj('events').raw.keys) k: j.obj('events').obj(k),
      },
      sheets = j.objs('fxSheets').map(FxSheetDef.fromJson).toList(),
      projectiles = {
        for (final k in j.obj('projectiles').raw.keys) k: ProjectileStyle.fromJson(j.obj('projectiles').obj(k)),
      },
      projectileAliases = {
        for (final e in j.obj('projectileAliases').raw.entries) e.key: e.value as String,
      },
      projectileDefault = j.str('projectileDefault'),
      sheetColors = {
        for (final e in j.obj('sheetColors').raw.entries) e.key: parseArgb(e.value as String, 'sheetColors.${e.key}'),
      },
      sheetFrameMs = j.number('sheetFrameMs'),
      skillFxScale = j.number('skillFxScale'),
      ultimates = {for (final k in j.obj('ultimates').raw.keys) k: UltimatePattern.fromJson(j.obj('ultimates').obj(k))},
      enemyLook = {for (final k in j.obj('enemyLook').raw.keys) k: EnemyLook.fromJson(j.obj('enemyLook').obj(k))},
      enemySmallSize = j.number('enemySmallSize'),
      backgrounds = {for (final k in j.obj('backgrounds').raw.keys) k: j.obj('backgrounds').obj(k)},
      backgroundDefault = j.str('backgroundDefault'),
      backgroundFadeMs = j.number('backgroundFadeMs'),
      bossLook = {for (final k in j.obj('bossLook').raw.keys) k: j.obj('bossLook').obj(k)},
      bossLookDefault = j.str('bossLookDefault'),
      tierColors = [for (final c in j.strs('tierColors')) parseArgb(c, 'tierColors')];

  final Map<String, JsonReader> events;
  final List<FxSheetDef> sheets;
  final Map<String, ProjectileStyle> projectiles;
  final Map<String, String> projectileAliases;
  final String projectileDefault;

  /// 아트가 없을 때 시트를 대신 그리는 단색.
  final Map<String, int> sheetColors;
  final double sheetFrameMs;

  /// M3·해역·아트·사운드 연출 (render-m3-fx · render-regions · render-art-pack-v02 · render-audio · render-status 스펙).
  final double skillFxScale;
  final double enemySmallSize;
  final double backgroundFadeMs;
  final Map<String, UltimatePattern> ultimates;
  final Map<String, EnemyLook> enemyLook;
  final Map<String, JsonReader> backgrounds;
  final Map<String, JsonReader> bossLook;
  final String backgroundDefault;
  final String bossLookDefault;

  final List<int> tierColors; // 무한 항해 테두리 tier 1~3 색

  /// fx_map.json 원문. 아래 설정 묶음은 처음 읽을 때 한 번만 만든다(프레임당 할당 없음).
  final JsonReader raw;
  final Map<String, JsonReader> _objs = {};
  JsonReader _o(String key) => _objs[key] ??= raw.obj(key);

  JsonReader get screenSkill => _o('screenSkill');
  JsonReader get shipSkill => _o('shipSkill');
  JsonReader get split => _o('split');
  JsonReader get revive => _o('revive');
  JsonReader get stun => _o('stun');
  JsonReader get bossEntrance => _o('bossEntrance');
  JsonReader get bossFailed => _o('bossFailed');
  JsonReader get shield => _o('shield');
  JsonReader get chest => _o('chest');
  JsonReader get sprites => _o('sprites');
  JsonReader get audio => _o('audio');
  JsonReader get zone => _o('zone');
  JsonReader get status => _o('status');
  JsonReader get cutIn => _o('cutIn');
  JsonReader get pillar => _o('pillar');
  JsonReader get shipLook => _o('shipLook');
  JsonReader get regionSweep => _o('regionSweep');

  /// render-quality-v1 (기준 battle_ship.gif): 배경 배치, 시트 기준점, 계열 색, 콤보 배너, 캔버스 HUD, 슬롯, 포구 화염.
  JsonReader get backgroundLayout => _o('backgroundLayout');
  JsonReader get sheetAnchors => _o('sheetAnchors');
  JsonReader get familyColors => _o('familyColors');
  JsonReader get combo => _o('combo');
  JsonReader get hud => _o('hud');
  JsonReader get slots => _o('slots');
  JsonReader get muzzle => _o('muzzle');

  /// 계열 이름 → 발사체 모양. 별칭(옛 이름)을 풀고, 모르는 계열은 기본 모양.
  ProjectileStyle projectileFor(String family) =>
      projectiles[projectileAliases[family] ?? family] ?? projectiles[projectileDefault]!;

  FxSheetDef? sheet(String id) {
    for (final s in sheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 이벤트 키(`damage`, `kill` …)의 이펙트 시트 id.
  String? fxFor(String event) => events[event]?.strOrNull('fx');

  List<String> validate() {
    final e = <String>[];
    final ids = sheets.map((s) => s.id).toSet();
    for (final ev in events.entries) {
      final fx = ev.value.strOrNull('fx');
      expect(e, that: fx == null || ids.contains(fx), message: 'fx_map: ${ev.key}의 fx $fx가 fxSheets에 없음');
    }
    expect(e, that: projectiles.containsKey(projectileDefault), message: 'fx_map: projectileDefault가 projectiles에 없음');
    for (final a in projectileAliases.entries) {
      expect(e, that: projectiles.containsKey(a.value), message: 'fx_map: 별칭 ${a.key} → ${a.value}가 projectiles에 없음');
    }
    for (final id in ids) {
      expect(e, that: sheetColors.containsKey(id), message: 'fx_map: sheetColors에 $id 없음');
    }
    for (final u in ultimates.entries) {
      expect(e, that: ids.contains(u.value.fx), message: 'fx_map: ultimates.${u.key}의 fx ${u.value.fx}가 fxSheets에 없음');
    }
    expect(e, that: enemyLook.containsKey('basic'), message: 'fx_map: enemyLook.basic 없음');
    expect(e, that: backgrounds.containsKey(backgroundDefault), message: 'fx_map: backgroundDefault가 backgrounds에 없음');
    expect(e, that: bossLook.containsKey(bossLookDefault), message: 'fx_map: bossLookDefault가 bossLook에 없음');
    expect(e, that: tierColors.length == 3, message: 'fx_map: tierColors는 tier 1~3의 3개');
    for (final k in ['split', 'revive']) {
      final fx = (k == 'split' ? split : revive).str('fx');
      expect(e, that: ids.contains(fx), message: 'fx_map: $k.fx $fx가 fxSheets에 없음');
    }
    return e;
  }
}
