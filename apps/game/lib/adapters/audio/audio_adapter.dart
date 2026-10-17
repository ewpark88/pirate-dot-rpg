import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:game_core/contracts.dart';
import 'package:pirate_dot/adapters/audio/audio_sdk.dart';

/// 효과음·배경음 (스펙 platform-m4 d). 파일 규칙 `sfx/<id>.ogg`·`sfx/<id>_<n>.ogg`·`bgm/<id>.ogg`.
/// 없는 파일은 무음 — 음원을 사람이 고르기 전에도 그대로 돈다.
class AudioAdapter implements AudioPort {
  AudioAdapter._(this._sdk, this._files, this._nowMs);

  /// 목록을 못 읽으면 빈 목록(전부 무음).
  /// [timeout]: 목록 읽기가 이보다 오래 걸리면 무음으로 시작한다(첫 프레임을 막지 않게).
  /// [nowMs]: 같은 소리 간격을 잴 시계(테스트가 넣는다, 기본 앱 시작부터 ms).
  static Future<AudioAdapter> load(AudioSdk sdk, {Duration? timeout, int Function()? nowMs}) async {
    var files = <String>{};
    try {
      final listing = sdk.listAssets();
      files = await (timeout == null ? listing : listing.timeout(timeout));
    } on Object catch (e) {
      debugPrint('audio: asset list failed — silent ($e)');
    }
    final clock = Stopwatch()..start();
    return AudioAdapter._(sdk, files, nowMs ?? () => clock.elapsedMilliseconds);
  }

  /// 같은 효과음 동시 재생 상한 (많은 처치가 겹칠 때 소리 뭉침 방지).
  static const maxSameSfx = 4;

  /// 모든 효과음 동시 재생 상한 · 같은 효과음 다시 낼 최소 간격(ms) — 발열 대책(실기기 오디오 CPU 56%, 2026-10-17).
  static const maxTotalSfx = 6;
  static const sameSfxGapMs = 60;

  /// 효과음 재생 요청이 이 시간 안에 끝나지 않으면(플랫폼 응답 없음) 동시 수 자리를 돌려준다 — 자리가 갇혀 효과음이 영영
  /// 안 나는 일이 없게(사용자 폰 버그 2026-10-17 회귀 방지).
  static const sfxSlotTimeout = Duration(seconds: 2);

  /// 배경음을 다른 곡으로 바꿀 때 페이드 아웃·인 각각의 시간과 단계 수(피버 전용 곡 전환, 사용자 피드백 #23 — 해역 이동도 같이 부드럽게).
  static const bgmFadeMs = 400;
  static const bgmFadeSteps = 8;

  /// 배경음 기본 믹스 — 효과음 대비 0.7배(약 −3dB, S3 사운드 점검: 타격음이 산다). 설정 음량에 곱한다.
  static const bgmMix = 0.7;

  final AudioSdk _sdk;
  final Set<String> _files;
  final _active = <String, int>{};
  final _lastAt = <String, int>{};
  final int Function() _nowMs;
  int _total = 0;
  bool _quiet = false;
  double _sfx = 1;
  double _bgm = bgmMix;
  String? _bgmId;
  bool _bgmPlaying = false;
  int _fadeGen = 0; // 페이드가 겹치면 앞의 것을 버린다

  /// 지금 동시 재생 상한(발열이 심하면 main이 줄인다 — power_policy sfxMaxTotal).
  int maxTotal = maxTotalSfx;

  bool hasSfx(String id) => _files.contains(_sfxPath(id));

  /// 방치·절전 화면·발열 심함이면 효과음을 끈다(배경음만, power_channel sfxQuiet).
  // ignore: avoid_setters_without_getters
  set quiet(bool on) => _quiet = on;

  bool _suspended = false;

  /// 광고가 화면을 덮는 동안: 효과음을 끊고 받지 않으며, 배경음은 일시정지.
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _fire(_sdk.stopAllSfx());
    if (_bgmPlaying) _fire(_sdk.pauseBgm());
  }

  /// 광고가 닫히면 다시 (배경음은 울리던 경우만 이어서).
  void unsuspend() {
    if (!_suspended) return;
    _suspended = false;
    if (_bgmPlaying) _fire(_sdk.resumeBgm());
  }

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) {
    if (_sfx <= 0 || _suspended || _quiet || _total >= maxTotal) return;
    final varied = _sfxPath('${id}_$variant');
    final path = _files.contains(varied) ? varied : _sfxPath(id);
    if (!_files.contains(path)) return;
    final n = _active[id] ?? 0;
    final now = _nowMs();
    if (n >= maxSameSfx || now - (_lastAt[path] ?? -sameSfxGapMs) < sameSfxGapMs) return; // 같은 파일 간격
    _active[id] = n + 1;
    _lastAt[path] = now;
    _total += 1;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _active[id] = (_active[id] ?? 1) - 1;
      _total -= 1;
    }

    _fire(_sdk.playSfx(path, volume: _sfx, rate: pitch).timeout(sfxSlotTimeout).whenComplete(release));
  }

  @override
  void playBgm(String id) {
    if (_bgmId == id && _bgmPlaying) return;
    final switching = _bgmPlaying && _bgmId != null && !_suspended;
    _bgmId = id;
    if (switching) {
      unawaited(_crossfade());
    } else {
      _fadeGen++;
      _startBgm();
    }
  }

  /// 지금 곡을 [bgmFadeMs] 동안 줄이고 → 새 곡을 0에서 시작해 [bgmFadeMs] 동안 키운다.
  Future<void> _crossfade() async {
    final gen = ++_fadeGen;
    const step = Duration(milliseconds: bgmFadeMs ~/ bgmFadeSteps);
    for (var i = bgmFadeSteps - 1; i >= 0; i--) {
      await Future<void>.delayed(step);
      if (gen != _fadeGen) return;
      _fire(_sdk.setBgmVolume(_bgm * i / bgmFadeSteps));
    }
    if (!_startBgm(volume: 0)) return;
    for (var i = 1; i <= bgmFadeSteps; i++) {
      await Future<void>.delayed(step);
      if (gen != _fadeGen) return;
      _fire(_sdk.setBgmVolume(_bgm * i / bgmFadeSteps));
    }
  }

  @override
  void stopBgm() {
    _fadeGen++;
    _bgmId = null;
    _bgmPlaying = false;
    _fire(_sdk.stopBgm());
  }

  @override
  void setVolumes({required double sfx, required double bgm}) {
    _sfx = sfx;
    _bgm = bgm * bgmMix;
    if (_bgmPlaying) {
      _fire(_sdk.setBgmVolume(_bgm));
    } else {
      _startBgm();
    }
  }

  /// 백그라운드로 갈 때·돌아올 때 (main.dart의 생명주기에서).
  void pauseBgm() => _fire(_sdk.pauseBgm());

  void resumeBgm() => _fire(_sdk.resumeBgm());

  /// 지금 곡(_bgmId)을 [volume](없으면 설정 음량)으로 튼다. 틀었으면 true.
  bool _startBgm({double? volume}) {
    final id = _bgmId;
    if (id == null || _bgm <= 0) return false;
    final path = 'bgm/$id.ogg';
    if (!_files.contains(path)) return false;
    _bgmPlaying = true;
    _fire(_sdk.playBgm(path, volume: volume ?? _bgm));
    return true;
  }

  static String _sfxPath(String name) => 'sfx/$name.ogg';

  static void _fire(Future<void> f) => unawaited(f.catchError((Object e) => debugPrint('audio: $e')));
}
