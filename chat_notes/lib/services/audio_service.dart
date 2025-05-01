import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initRecorder();
  }

  late final AudioRecorder _audioRecorder;
  final _audioPlayer = AudioPlayer();
  
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  double _amplitude = 0.0;
  final StreamController<int> _durationStreamController = StreamController<int>.broadcast();
  final StreamController<double> _amplitudeStreamController = StreamController<double>.broadcast();
  
  Stream<int> get durationStream => _durationStreamController.stream;
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  bool get isRecording => _recordingTimer != null;
  int get recordingDuration => _recordingDuration;
  double get currentAmplitude => _amplitude;

  void _initRecorder() {
    _audioRecorder = AudioRecorder();
  }

  Future<bool> checkPermission() async {
    if (await Permission.microphone.isGranted) {
      return true;
    }
    
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    if (!await checkPermission()) {
      return false;
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Get the recording path
      final directory = await getTemporaryDirectory();
      final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path.join(directory.path, fileName);

      // Configure recorder
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      
      await _audioRecorder.start(config, path: _recordingPath!);
      
      // Start amplitude monitoring - using a timer since direct stream isn't available in this version
      _recordingDuration = 0;
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
        if (timer.tick % 5 == 0) {
          // Update duration every second (5 * 200ms = 1s)
          _recordingDuration++;
          _durationStreamController.add(_recordingDuration);
        }
        
        try {
          // Get amplitude manually
          final amplitude = await _audioRecorder.getAmplitude();
          _amplitude = min(1.0, amplitude.current / 100);
          _amplitudeStreamController.add(_amplitude);
        } catch (e) {
          // Ignore amplitude errors
          debugPrint('Error getting amplitude: $e');
        }
      });
      
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!isRecording) return null;
    
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    try {
      await _audioRecorder.stop();
      return _recordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    final String? filePath = _recordingPath;
    
    await stopRecording();
    
    if (filePath != null) {
      try {
        await _audioRecorder.cancel();
      } catch (e) {
        debugPrint('Error canceling recording: $e');
      }
    }
  }

  Future<void> playAudio(String filePath) async {
    try {
      // Configure audio session to force playback through main speaker
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _audioPlayer.dispose();
    await _durationStreamController.close();
    await _amplitudeStreamController.close();
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 