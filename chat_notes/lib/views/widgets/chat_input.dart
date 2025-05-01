import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController textController;
  final Function(String, List<String>, String?, double?, double?, String?, String?) onSubmitted;

  const ChatInput({
    super.key,
    required this.textController,
    required this.onSubmitted,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final FocusNode _focusNode = FocusNode();
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  bool _showOptions = false;
  String? _lastRecordingPath;
  
  // Location data
  Position? _currentLocation;
  String? _locationName;
  bool _isGettingLocation = false;
  
  // Tags
  List<String> _selectedTags = [];
  final List<String> _availableTags = ['Important', 'Work', 'Personal', 'Ideas', 'Todo'];
  bool _showTagSelector = false;
  
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _audioService.dispose();
    widget.textController.removeListener(() => setState(() {}));
    super.dispose();
  }
  
  bool get _hasText => widget.textController.text.trim().isNotEmpty;
  bool get _canSend => _hasText || _lastRecordingPath != null;

  Future<void> _startRecording() async {
    final success = await _audioService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _showOptions = false;
        _showTagSelector = false;
      });
    }
  }
  
  Future<void> _stopRecording({bool canceled = false}) async {
    if (canceled) {
      await _audioService.cancelRecording();
      setState(() {
        _isRecording = false;
        _lastRecordingPath = null;
      });
      return;
    }
    
    final audioPath = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _lastRecordingPath = audioPath;
    });
  }
  
  Future<void> _playRecording() async {
    if (_lastRecordingPath != null) {
      await _audioService.playAudio(_lastRecordingPath!);
    }
  }
  
  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
      _showOptions = false;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getLocationAddress();
      
      setState(() {
        _currentLocation = position;
        _locationName = address;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }
  
  void _toggleTagSelector() {
    setState(() {
      _showTagSelector = !_showTagSelector;
      _showOptions = false;
    });
  }
  
  void _toggleOptions() {
    setState(() {
      _showOptions = !_showOptions;
      if (_showOptions) {
        _showTagSelector = false;
        _focusNode.unfocus();
      }
    });
  }
  
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }
  
  void _clearLocation() {
    setState(() {
      _currentLocation = null;
      _locationName = null;
    });
  }
  
  void _sendMessage() {
    final text = widget.textController.text;
    final hasVoiceMessage = _lastRecordingPath != null;
    
    // Allow sending when there's either text or a voice recording
    if (text.isNotEmpty || hasVoiceMessage) {
      widget.onSubmitted(
        text,
        _selectedTags,
        null,
        _currentLocation?.latitude,
        _currentLocation?.longitude,
        _locationName,
        _lastRecordingPath,
      );
      widget.textController.clear();
      setState(() {
        _selectedTags = [];
        _currentLocation = null;
        _locationName = null;
        _showTagSelector = false;
        _lastRecordingPath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tag selector
            if (_showTagSelector)
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? const Color(0xFF303030) : Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Tags:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (_) => _toggleTag(tag),
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          selectedColor: Colors.blue.withOpacity(0.2),
                          checkmarkColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: isSelected 
                                ? Colors.blue 
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
            // Location indicator
            if (_currentLocation != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: isDark 
                    ? Colors.blue.shade900.withOpacity(0.2)
                    : Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: isDark ? Colors.blue.shade300 : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationName ?? 'Location attached',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: isDark ? Colors.red.shade300 : Colors.red,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _clearLocation,
                    ),
                  ],
                ),
              ),
            
            // Voice recording indicator
            if (_lastRecordingPath != null && !_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.shade900.withOpacity(0.1) : Colors.orange.shade50,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.orange.shade800.withOpacity(0.2) : Colors.orange.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.shade800.withOpacity(0.3) : Colors.orange.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: isDark ? Colors.white : Colors.orange.shade800,
                        ),
                        onPressed: _playRecording,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Voice message",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Duration: ${_audioService.formatDuration(_audioService.recordingDuration)}",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 24,
                          color: isDark ? Colors.red.shade300 : Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _lastRecordingPath = null;
                            widget.textController.clear();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            // Recording UI overlay
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                color: isDark ? Colors.red.shade900.withOpacity(0.1) : Colors.red.shade50,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          child: StreamBuilder<double>(
                            stream: _audioService.amplitudeStream,
                            builder: (context, snapshot) {
                              final amplitude = snapshot.data ?? 0.0;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 48 * amplitude.clamp(0.1, 1.0),
                                    height: 48 * amplitude.clamp(0.1, 1.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.withOpacity(0.3 + amplitude * 0.5),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.mic,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recording voice message...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _audioService.formatDuration(_audioService.recordingDuration),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _stopRecording(canceled: true),
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _stopRecording(),
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.green,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Send',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<double>(
                      stream: _audioService.amplitudeStream,
                      builder: (context, snapshot) {
                        final amplitude = snapshot.data ?? 0.0;
                        return Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              35, // Number of bars
                              (index) {
                                // Create dynamic heights based on position and current amplitude
                                final position = index / 34; // 0.0 to 1.0
                                final diff = 1 - (position - amplitude).abs() * 2;
                                final barHeight = 5 + diff * 35;
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 50),
                                  width: 3,
                                  height: barHeight.clamp(5, 40),
                                  decoration: BoxDecoration(
                                    color: HSLColor.fromAHSL(
                                      1.0,
                                      (360 * position) % 360, // Hue
                                      0.7, // Saturation
                                      0.5, // Lightness
                                    ).withOpacity(diff.clamp(0.3, 1.0)).toColor(),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            
            // Options panel
            if (_showOptions && !_isRecording)
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOptionButton(
                      icon: Icons.tag,
                      label: 'Tags',
                      onTap: _toggleTagSelector,
                      isDark: isDark,
                      color: Colors.blue,
                    ),
                    _buildOptionButton(
                      icon: Icons.location_on,
                      label: 'Location',
                      onTap: _getLocation,
                      isLoading: _isGettingLocation,
                      isDark: isDark,
                      color: Colors.green,
                    ),
                    _buildOptionButton(
                      icon: Icons.mic,
                      label: 'Record',
                      onTap: _startRecording,
                      isDark: isDark,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            
            // Input bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Add button
                  IconButton(
                    icon: Icon(
                      _showOptions ? Icons.close : Icons.add,
                      color: _showOptions 
                          ? (isDark ? Colors.red.shade300 : Colors.red) 
                          : (isDark ? Colors.blue.shade300 : Colors.blue),
                      size: 28,
                    ),
                    onPressed: _toggleOptions,
                  ),
                  
                  // Text field
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: widget.textController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey,
                              fontSize: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Send button
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: _canSend
                          ? (isDark ? Colors.blue.shade300 : Colors.blue)
                          : Colors.grey.shade400,
                      size: 28,
                    ),
                    onPressed: _canSend ? _sendMessage : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isDark ? color.withOpacity(0.8) : color,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}