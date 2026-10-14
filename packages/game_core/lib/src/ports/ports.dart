// 코어가 바깥 세계(시계·난수·파일·광고·분석·서버·결제)를 만나는 유일한 길.
// 테스트는 lib/testing.dart의 가짜 구현을, 앱은 apps/game/lib/adapters/의 진짜 구현을 끼운다.

/// 현재 시각. 코어에서 DateTime.now()를 직접 부르지 않는다.
abstract interface class Clock {
  /// UTC.
  DateTime now();
}

/// 시드 고정 난수. 같은 시드 → 같은 수열.
abstract interface class Rng {
  /// [0, 1).
  double nextDouble();

  /// [0, max).
  int nextInt(int max);

  /// 현재 내부 상태. 세이브에 넣어 이어서 굴린다.
  int get state;
}

/// 세이브 파일 저장소. 원자적 쓰기·백업은 구현이 책임진다.
abstract interface class SaveStore {
  /// 저장된 원문(JSON). 없으면 null.
  Future<String?> read();

  /// 직전 백업(save.bak) 원문. 없으면 null.
  Future<String?> readBackup();

  Future<void> write(String json);
}

/// 보상형 광고 장치 id (ads.json의 placements[].id).
enum AdPlacement { chest, tailwind, offline, bossSupport, freeSummon }

enum AdResult { rewarded, dismissed, failed, notLoaded }

/// 보상형 광고. 보상 지급은 SDK의 보상 콜백(=rewarded)에서만 한다.
abstract interface class AdsPort {
  bool isReady(AdPlacement placement);

  Future<AdResult> show(AdPlacement placement);
}

abstract interface class AnalyticsPort {
  void log(String event, [Map<String, Object> params = const {}]);

  /// 이탈 분석: 마지막 화면·스테이지 (설계서 4.9).
  void setLastSeen({required String screen, required int stage});
}

/// 랭킹 보드 (설계서 8.2).
enum Board { bestStage, weeklyStage, power }

class ScoreSubmission {
  const ScoreSubmission({
    required this.board,
    required this.value,
    required this.upgradeLevelSum,
    required this.crewCount,
    required this.rebirths,
  });

  final Board board;
  final int value;

  /// 서버의 전투력 대조용 요약 (설계서 8.3).
  final int upgradeLevelSum;
  final int crewCount;
  final int rebirths;
}

class RankEntry {
  const RankEntry({required this.rank, required this.nickname, required this.value});

  final int rank;
  final String nickname;
  final int value;
}

/// 1차: NoopLeaderboard, 2차: CloudflareLeaderboard.
abstract interface class LeaderboardPort {
  /// 신기록일 때만 호출.
  Future<void> submit(ScoreSubmission s);

  Future<List<RankEntry>> top(Board board, {int limit = 100});

  Future<RankEntry?> me(Board board);
}

/// IAP 자리(2차 이후). 1차에는 구현이 없다.
abstract interface class PurchasePort {
  Future<bool> purchase(String productId);

  Future<Set<String>> owned();
}

/// 1차 랭킹: 아무것도 하지 않는다.
class NoopLeaderboard implements LeaderboardPort {
  const NoopLeaderboard();

  @override
  Future<void> submit(ScoreSubmission s) async {}

  @override
  Future<List<RankEntry>> top(Board board, {int limit = 100}) async => const [];

  @override
  Future<RankEntry?> me(Board board) async => null;
}

/// 효과음·배경음 (설계서 4.4 소리, 10장). 렌더가 이벤트를 보고 부르고, 앱 어댑터가 실제로 재생한다.
/// 엔진(코어)에는 주입하지 않는다 — 소리는 결정론 밖이다.
abstract interface class AudioPort {
  /// [id]는 fx_map.json의 sfx id. [variant]는 변형 번호(0부터), [pitch]는 재생 속도 배율(1 = 원래).
  void playSfx(String id, {int variant = 0, double pitch = 1});

  /// regions.json의 bgm id. 같은 곡이면 이어서 튼다.
  void playBgm(String id);

  void stopBgm();

  /// 0~1. 설정의 효과음·배경음 끄기는 0.
  void setVolumes({required double sfx, required double bgm});
}
