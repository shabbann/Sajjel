import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

// Custom Event Classes for Playback Streams
class PlaybackEvent<T> {
  final String? path;
  final T data;
  PlaybackEvent(this.path, this.data);
}

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initRecorder();
    _initStreamControllers();
    _setupPlaybackListeners(); // Setup listeners for the internal player
  }

  late final AudioRecorder _audioRecorder;
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  
  // Recording state
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  double _amplitude = 0.0;
  late StreamController<int> _recordingDurationController;
  late StreamController<double> _amplitudeStreamController;

  // Custom Stream Controllers for Playback
  late StreamController<PlaybackEvent<PlayerState>> _playbackStateController;
  late StreamController<PlaybackEvent<Duration>> _playbackPositionController;
  late StreamController<PlaybackEvent<Duration?>> _playbackDurationController;
  
  // ---- Public Streams ----
  // Recording streams
  Stream<int> get recordingDurationStream => _recordingDurationController.stream;
  Stream<double> get amplitudeStream => _amplitudeStreamController.stream;
  
  // Playback streams (Custom events)
  Stream<PlaybackEvent<PlayerState>> get playbackStateStream => _playbackStateController.stream;
  Stream<PlaybackEvent<Duration>> get playbackPositionStream => _playbackPositionController.stream;
  Stream<PlaybackEvent<Duration?>> get playbackDurationStream => _playbackDurationController.stream;

  // Recording state getters
  bool get isRecording => _recordingTimer != null;
  int get recordingDuration => _recordingDuration;
  double get currentAmplitude => _amplitude;
  String? get currentRecordingPath => _recordingPath;
  // Playback state getter
  String? get currentlyPlayingPath => _currentlyPlayingPath;

  void _initRecorder() {
    _audioRecorder = AudioRecorder();
  }
  
  void _initStreamControllers() {
    // Initialize recording-specific controllers
    _recordingDurationController = StreamController<int>.broadcast();
    _amplitudeStreamController = StreamController<double>.broadcast();
    // Initialize playback-specific controllers
    _playbackStateController = StreamController<PlaybackEvent<PlayerState>>.broadcast();
    _playbackPositionController = StreamController<PlaybackEvent<Duration>>.broadcast();
    _playbackDurationController = StreamController<PlaybackEvent<Duration?>>.broadcast();
  }

  void _setupPlaybackListeners() {
    _audioPlayer.positionStream.listen((position) {
      _safeAddToPlaybackStream(_playbackPositionController, PlaybackEvent(_currentlyPlayingPath, position));
    });
    _audioPlayer.durationStream.listen((duration) {
      _safeAddToPlaybackStream(_playbackDurationController, PlaybackEvent(_currentlyPlayingPath, duration));
    });
    _audioPlayer.playerStateStream.listen((state) {
       _safeAddToPlaybackStream(_playbackStateController, PlaybackEvent(_currentlyPlayingPath, state));
       // If playback completed, clear the currently playing path
       if (state.processingState == ProcessingState.completed) {
         _currentlyPlayingPath = null;
       }
    });
  }

  // Helper to safely add to broadcast streams
  void _safeAddToPlaybackStream<T>(StreamController<T> controller, T event) {
    if (!controller.isClosed) {
      controller.add(event);
    }
  }

  // --- Playback Methods ---

  Future<void> playAudio(String path) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
      
      // Stop previous if different path or if not playing
      if (_currentlyPlayingPath != path || !_audioPlayer.playing) {
         await _audioPlayer.stop(); 
      }
      
      _currentlyPlayingPath = path;
      await _audioPlayer.setUrl('file://$path'); 
      await _audioPlayer.play(); 
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _currentlyPlayingPath = null; // Reset path on error
      rethrow; 
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _audioPlayer.stop();
      _currentlyPlayingPath = null; // Clear path on explicit stop
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }

  Future<void> seek(Duration position) async {
    // Seeking doesn't change the currently playing file
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }
  
  Future<Duration?> getDuration() async {
     return _audioPlayer.duration;
  }

  // --- Recording Methods ---

  Future<bool> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        // Can't request automatically, user needs to enable in settings
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    await _safeStopExistingRecording();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    if (!await checkPermission()) {
      return false;
    }

    try {
      _recordingDuration = 0;
      _amplitude = 0.0;
      _recreateRecordingStreamControllers(); // Recreate recording streams
      
      // Configure audio session for recording
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        // ... other recording configurations ...
      ));

      final directory = await getTemporaryDirectory();
      final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path.join(directory.path, fileName);
      
      debugPrint("Starting recording to path: $_recordingPath");

      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      
      final recordingFile = File(_recordingPath!);
      if (!await recordingFile.parent.exists()) {
        await recordingFile.parent.create(recursive: true);
      }
      
      await _audioRecorder.start(config, path: _recordingPath!);
      
      // Start monitoring timer
      Timer? newTimer;
      newTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
        if (_recordingTimer != newTimer) {
          timer.cancel();
          return;
        }
        try {
          if (timer.tick % 5 == 0) {
            _recordingDuration++;
            _safeAddToRecordingDurationStream(_recordingDuration);
          }
          if (_recordingTimer != null && timer == _recordingTimer && await _audioRecorder.isRecording()) {
            final amp = await _audioRecorder.getAmplitude();
            _amplitude = math.min(1.0, amp.current / 100);
            _safeAddToAmplitudeStream(_amplitude);
          } else {
            timer.cancel();
          }
        } catch (e) {
          debugPrint('Non-fatal error in recording timer: $e');
        }
      });
      _recordingTimer = newTimer;
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _safeCleanupRecordingState();
      return false;
    }
  }
  
  void _safeAddToRecordingDurationStream(int duration) {
    try {
      if (!_recordingDurationController.isClosed) {
        _recordingDurationController.add(duration);
      }
    } catch (e) {
      debugPrint('Error adding to recording duration stream: $e');
    }
  }
  
  void _safeAddToAmplitudeStream(double amplitude) {
    try {
      if (!_amplitudeStreamController.isClosed) {
        _amplitudeStreamController.add(amplitude);
      }
    } catch (e) {
      debugPrint('Error adding to amplitude stream: $e');
    }
  }

  Future<void> _safeStopExistingRecording() async {
    try {
      if (_recordingTimer != null) {
        _recordingTimer!.cancel();
        _recordingTimer = null;
      }
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('Error while safely stopping existing recording: $e');
    }
  }
  
  void _safeCleanupRecordingState() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingPath = null;
    _recordingDuration = 0;
    _amplitude = 0.0;
    _recreateRecordingStreamControllers();
  }
  
  void _recreateRecordingStreamControllers() {
    try {
      if (!_recordingDurationController.isClosed) {
        _recordingDurationController.close();
      }
    } catch (e) {
      debugPrint('Error closing recording duration controller: $e');
    }
    try {
      if (!_amplitudeStreamController.isClosed) {
        _amplitudeStreamController.close();
      }
    } catch (e) {
      debugPrint('Error closing amplitude controller: $e');
    }
    _recordingDurationController = StreamController<int>.broadcast();
    _amplitudeStreamController = StreamController<double>.broadcast();
  }

  Future<String?> stopRecording() async {
    if (!isRecording) return null;
    final String? savedPath = _recordingPath;
    debugPrint("Stopping recording. Current path: $savedPath");
    
    try {
      await _safeStopExistingRecording(); // Stops recorder and cancels timer
      _recordingPath = null; // Clear internal path after stopping
      _recordingDuration = 0;
      _amplitude = 0.0;
      
      // Close recording-specific streams after stopping
      // Playback streams remain open as they belong to AudioPlayer
      _closeRecordingStreams(); 

      if (savedPath != null && await File(savedPath).exists()) {
         debugPrint("Recording stopped successfully. Path: $savedPath");
        return savedPath;
      } else {
         debugPrint("Recording file doesn't exist after stopping. Path: $savedPath");
        return null;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _safeCleanupRecordingState();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!isRecording) return;
    final String? pathToDelete = _recordingPath;
    debugPrint("Canceling recording. Path to delete: $pathToDelete");
    
    try {
      await _safeStopExistingRecording();
      _recordingPath = null;
      _recordingDuration = 0;
      _amplitude = 0.0;
      _closeRecordingStreams();
      
      // Delete the incomplete file
      if (pathToDelete != null) {
        final file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
          debugPrint("Deleted canceled recording file: $pathToDelete");
        }
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
      _safeCleanupRecordingState();
    }
  }

  void _closeRecordingStreams() {
      try {
         if (!_recordingDurationController.isClosed) {
           _recordingDurationController.close();
         }
       } catch (e) { /* Ignore */ }
       try {
         if (!_amplitudeStreamController.isClosed) {
           _amplitudeStreamController.close();
         }
       } catch (e) { /* Ignore */ }
  }

  // Consider if dispose is needed if it's a singleton
  void dispose() {
    // _audioRecorder.dispose(); // Dispose recorder if necessary
    _audioPlayer.dispose(); // Dispose player
    _recordingTimer?.cancel();
    // Close any remaining stream controllers
    _closeRecordingStreams();
    debugPrint("AudioService disposed");
  }

  String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 