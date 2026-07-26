import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Loud, looping SOS siren played on the guardian's device when a patient's
/// emergency alert arrives. Uses the Android ALARM audio stream so it plays
/// at alarm volume even when the phone is on silent/DND.
class SosAlarmService {
  SosAlarmService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _ringing = false;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ));
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/sos_siren.wav'));
    } catch (e) {
      debugPrint('[SOS] alarm start ERROR: $e');
    }
  }

  static Future<void> stop() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[SOS] alarm stop ERROR: $e');
    }
  }

  static bool get isRinging => _ringing;
}
