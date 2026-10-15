import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:game_core/contracts.dart';
import 'package:pirate_dot/adapters/audio/audio_sdk.dart';

/// 효과음·배경음 (스펙 platform-m4 d). 파일 규칙 `sfx/<id>.ogg`·`sfx/<id>_<n>.ogg`·`bgm/<id>.ogg`.
/// 없는 파일은 무음 — 음원을 사람이 고르기 전에도 그대로 돈다.
class AudioAdapter implements AudioPort {
  AudioAdapter._(this._sdk, this._files);

  /// 목록을 못 읽으면 빈 목록(전부 무음).
  /// [timeout]: 목록 읽기가 이보다 오래 걸리면 무음으로 시작한다(첫 프레임을 막지 않게).
  static Future<AudioAdapter> load(AudioSdk sdk, {Duration? timeout}) async {
    var files = <String>{};
    try {
      final listing = sdk.listAssets();
      files = await (timeout == null ? listing : listing.timeout(timeout));
    } on Object catch (e) {
      debugPrint('audio: asset list failed — silent ($e)');
    }
    return AudioAdapter._(sdk, files);
  }

  /// 같은 효과음 동시 재생 상한 (많은 처치가 겹칠 때 소리 뭉침 방지).
  static const maxSameSfx = 4;

  final AudioSdk _sdk;
  final Set<String> _files;
  final _active = <String, int>{};
  double _sfx = 1;
  double _bgm = 1;
  String? _bgmId;
  bool _bgmPlaying = false;

  bool hasSfx(String id) => _files.contains(_sfxPath(id));

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) {
    if (_sfx <= 0) return;
    final varied = _sfxPath('${id}_$variant');
    final path = _files.contains(varied) ? varied : _sfxPath(id);
    if (!_files.contains(path)) return;
    final n = _active[id] ?? 0;
    if (n >= maxSameSfx) return;
    _active[id] = n + 1;
    _fire(_sdk.playSfx(path, volume: _sfx, rate: pitch).whenComplete(() => _active[id] = (_active[id] ?? 1) - 1));
  }

  @override
  void playBgm(String id) {
    if (_bgmId == id && _bgmPlaying) return;
    _bgmId = id;
    _startBgm();
  }

  @override
  void stopBgm() {
    _bgmId = null;
    _bgmPlaying = false;
    _fire(_sdk.stopBgm());
  }

  @override
  void setVolumes({required double sfx, required double bgm}) {
    _sfx = sfx;
    _bgm = bgm;
    if (_bgmPlaying) {
      _fire(_sdk.setBgmVolume(bgm));
    } else {
      _startBgm();
    }
  }

  /// 백그라운드로 갈 때·돌아올 때 (main.dart의 생명주기에서).
  void pauseBgm() => _fire(_sdk.pauseBgm());

  void resumeBgm() => _fire(_sdk.resumeBgm());

  void _startBgm() {
    final id = _bgmId;
    if (id == null || _bgm <= 0) return;
    final path = 'bgm/$id.ogg';
    if (!_files.contains(path)) return;
    _bgmPlaying = true;
    _fire(_sdk.playBgm(path, volume: _bgm));
  }

  static String _sfxPath(String name) => 'sfx/$name.ogg';

  static void _fire(Future<void> f) => unawaited(f.catchError((Object e) => debugPrint('audio: $e')));
}
