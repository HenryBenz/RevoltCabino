import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../game/simulation/simulation.dart';
import '../../models/core.dart';
import '../../models/game_state.dart';
import '../../models/level.dart';
import '../save/save_data.dart';

enum MusicTrack {
  menu('audio/music/music_menu_ambient.m4a'),
  gameplay('audio/music/music_gameplay_ambient.m4a'),
  finale('audio/music/music_final_sector.m4a');

  const MusicTrack(this.asset);

  final String asset;
}

enum Sfx {
  tap('audio/sfx/sfx_ui_tap.wav'),
  back('audio/sfx/sfx_ui_back.wav'),
  unavailable('audio/sfx/sfx_ui_unavailable.wav'),
  gravity('audio/sfx/sfx_gravity_change.wav'),
  playerSlide('audio/sfx/sfx_player_slide.wav'),
  cargoSlide('audio/sfx/sfx_cargo_slide.wav'),
  settle('audio/sfx/sfx_object_settle.wav'),
  plateOn('audio/sfx/sfx_plate_activate.wav'),
  plateOff('audio/sfx/sfx_plate_release.wav'),
  gateOpen('audio/sfx/sfx_gate_open.wav'),
  gateClose('audio/sfx/sfx_gate_close.wav'),
  magnetOn('audio/sfx/sfx_magnet_on.wav'),
  magnetOff('audio/sfx/sfx_magnet_off.wav'),
  fragment('audio/sfx/sfx_fragment_collect.wav'),
  failure('audio/sfx/sfx_laser_failure.wav'),
  undo('audio/sfx/sfx_undo.wav'),
  hint('audio/sfx/sfx_hint_reveal.wav'),
  level('audio/sfx/sfx_level_complete.wav'),
  chapter('audio/sfx/sfx_chapter_complete.wav'),
  campaign('audio/sfx/sfx_campaign_complete.wav');

  const Sfx(this.asset);

  final String asset;
}

class AudioService {
  final AudioPlayer _musicA = AudioPlayer();
  final AudioPlayer _musicB = AudioPlayer();
  final List<AudioPlayer> _effects = List.generate(4, (_) => AudioPlayer());

  MusicTrack? current;
  var _activeA = true;
  var _fade = 0;
  var ducked = false;
  var _paused = false;
  var _effectCursor = 0;
  SettingsData _settings = const SettingsData();

  SettingsData get settings => _settings;

  Future<void> prepare() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)),
    );
    for (final player in [_musicA, _musicB, ..._effects]) {
      await player.setReleaseMode(ReleaseMode.stop);
    }
  }

  Future<void> playMusic(MusicTrack track, SettingsData settings) async {
    try {
      await _playMusic(track, settings);
    } catch (_) {}
  }

  Future<void> _playMusic(MusicTrack track, SettingsData settings) async {
    _settings = settings;
    if (!settings.musicEnabled || settings.musicVolume <= 0) {
      current = null;
      await _musicA.stop();
      await _musicB.stop();
      return;
    }
    if (_paused) {
      current = track;
      return;
    }
    if (current == track) {
      await _applyMusicVolume();
      return;
    }
    final generation = ++_fade;
    final incoming = _activeA ? _musicB : _musicA;
    final outgoing = _activeA ? _musicA : _musicB;
    _activeA = !_activeA;
    current = track;
    await incoming.setReleaseMode(ReleaseMode.loop);
    await incoming.setVolume(0);
    await incoming.play(AssetSource(track.asset));
    const steps = 10;
    for (var step = 1; step <= steps; step++) {
      if (generation != _fade) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (generation != _fade) return;
      final blend = step / steps;
      await incoming.setVolume(_volume * blend);
      await outgoing.setVolume(_volume * (1 - blend));
    }
    if (generation == _fade) await outgoing.stop();
  }

  Future<void> applySettings(SettingsData settings) async {
    try {
      await _applySettings(settings);
    } catch (_) {}
  }

  Future<void> _applySettings(SettingsData settings) async {
    _settings = settings;
    if (current != null) {
      await playMusic(current!, settings);
    } else if (!settings.musicEnabled) {
      await _musicA.stop();
      await _musicB.stop();
    }
    await _applyMusicVolume();
  }

  Future<void> setDucked(bool value) async {
    ducked = value;
    try {
      await _applyMusicVolume();
    } catch (_) {}
  }

  Future<void> pauseOutput() async {
    _paused = true;
    try {
      await _musicA.pause();
      await _musicB.pause();
      for (final effect in _effects) {
        await effect.stop();
      }
    } catch (_) {}
  }

  Future<void> resumeOutput() async {
    _paused = false;
    if (current == null || !_settings.musicEnabled) return;
    try {
      final active = _activeA ? _musicA : _musicB;
      await active.resume();
      await _applyMusicVolume();
    } catch (_) {}
  }

  void play(Sfx effect) {
    try {
      if (!_settings.sfxEnabled || _settings.sfxVolume <= 0 || _paused) return;
      final player = _effects[_effectCursor];
      _effectCursor = (_effectCursor + 1) % _effects.length;
      player.setVolume(_settings.sfxVolume);
      unawaited(player.play(AssetSource(effect.asset)).catchError((Object _) {}));
    } catch (_) {}
  }

  void tap() {
    play(Sfx.tap);
    _haptic();
  }

  void back() {
    play(Sfx.back);
    _haptic();
  }

  void unavailable() {
    play(Sfx.unavailable);
  }

  void playResolution({
    required Level level,
    required GameState before,
    required GameAction action,
    required SimResult result,
  }) {
    if (result.outcome == Outcome.lost) {
      play(Sfx.failure);
      feedback(heavy: true);
      return;
    }
    switch (action) {
      case GravityAction():
        play(Sfx.gravity);
      case MagnetAction():
        play(before.magnetsEnabled ? Sfx.magnetOff : Sfx.magnetOn);
    }
    final cargoMoved = result.state.cargo.entries.any(
      (entry) => before.cargo[entry.key] != entry.value,
    );
    final playerMoved = result.state.player != before.player;
    if (cargoMoved) {
      play(Sfx.cargoSlide);
    } else if (playerMoved) {
      play(Sfx.playerSlide);
    }
    if (cargoMoved || playerMoved) play(Sfx.settle);
    final beforeFacts = inspect(level, before);
    final afterFacts = inspect(level, result.state);
    if (afterFacts.openGateIds.length > beforeFacts.openGateIds.length) {
      play(Sfx.gateOpen);
    } else if (afterFacts.openGateIds.length < beforeFacts.openGateIds.length) {
      play(Sfx.gateClose);
    } else if (afterFacts.activePlateIds.length > beforeFacts.activePlateIds.length) {
      play(Sfx.plateOn);
    } else if (afterFacts.activePlateIds.length < beforeFacts.activePlateIds.length) {
      play(Sfx.plateOff);
    }
    if (!before.fragmentCollected && result.state.fragmentCollected) {
      play(Sfx.fragment);
    }
    feedback();
  }

  void feedback({bool heavy = false}) {
    if (!_settings.hapticsEnabled) return;
    try {
      if (heavy) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  void _haptic() {
    if (!_settings.hapticsEnabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  double get _volume => _settings.musicVolume * (ducked ? 0.45 : 1);

  Future<void> _applyMusicVolume() async {
    final active = _activeA ? _musicA : _musicB;
    await active.setVolume(current == null ? 0 : _volume);
  }

}

class SoundScope extends InheritedWidget {
  const SoundScope({required this.audio, required super.child, super.key});

  final AudioService? audio;

  static SoundScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SoundScope>();
  }

  void tap() => audio?.tap();

  void back() => audio?.back();

  void unavailable() => audio?.unavailable();

  @override
  bool updateShouldNotify(SoundScope oldWidget) => oldWidget.audio != audio;
}
