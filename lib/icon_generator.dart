import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

// Run this file to generate the app icon
void main() {
  runApp(const IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IconGenerator(),
    );
  }
}

class IconGenerator extends StatefulWidget {
  @override
  _IconGeneratorState createState() => _IconGeneratorState();
}

class _IconGeneratorState extends State<IconGenerator> {
  final GlobalKey _globalKey = GlobalKey();
  bool _generating = false;
  String _status = 'Ready to generate icon';

  Future<void> _generateIcon() async {
    try {
      setState(() {
        _generating = true;
        _status = 'Generating icon...';
      });

      // Capture the widget as an image
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(1024);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        // Save the image to a file
        final directory = await getApplicationDocumentsDirectory();
        final assetsDir = Directory('${directory.path}/assets/icons');
        
        if (!await assetsDir.exists()) {
          await assetsDir.create(recursive: true);
        }
        
        // Save the full icon
        await File('${assetsDir.path}/app_icon.png').writeAsBytes(byteData.buffer.asUint8List());
        
        // Capture the foreground icon
        RenderRepaintBoundary foregroundBoundary = 
            _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        ui.Image foregroundImage = await foregroundBoundary.toImage(1024);
        ByteData? foregroundByteData = 
            await foregroundImage.toByteData(format: ui.ImageByteFormat.png);
            
        if (foregroundByteData != null) {
          await File('${assetsDir.path}/foreground.png')
              .writeAsBytes(foregroundByteData.buffer.asUint8List());
        }
        
        setState(() {
          _status = 'Icons generated at: ${assetsDir.path}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sajjel Icon Generator'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RepaintBoundary(
              key: _globalKey,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF3F51B5), // Indigo
                      const Color(0xFF2196F3), // Blue
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.note_alt_rounded,
                        size: 150,
                        color: Colors.white,
                      ),
                      const Text(
                        'S',
                        style: TextStyle(
                          fontSize: 100,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(_status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generating ? null : _generateIcon,
              child: Text(_generating ? 'Generating...' : 'Generate Icon'),
            ),
          ],
        ),
      ),
    );
  }
}

// Save icon image directly to the project
Future<void> saveIconsToAssets() async {
  final directory = Directory('assets/icons');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  
  // Create pixel data for the icon (simple blue icon with S)
  final iconData = generateIconPixelData(512, 512);
  final foregroundData = generateForegroundPixelData(512, 512);
  
  // Save as PNG files
  await File('assets/icons/app_icon.png').writeAsBytes(iconData);
  await File('assets/icons/foreground.png').writeAsBytes(foregroundData);
}

// Generate a blue gradient icon with S for Sajjel
List<int> generateIconPixelData(int width, int height) {
  final List<int> pixels = [];
  
  // Simple PNG header (very basic - you'd use a proper library in production)
  // This is a simplified version to demonstrate the concept
  pixels.addAll([137, 80, 78, 71, 13, 10, 26, 10]); // PNG signature
  
  // Create a blue to indigo gradient background with white S
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Blue gradient background
      int r = (63 + (x / width * 20)).round(); // Gradient from darker to lighter blue
      int g = (81 + (y / height * 20)).round();
      int b = 181;
      
      // Make corners transparent for rounded icon
      final double distanceFromCenter = _distanceFromCenter(x, y, width, height);
      if (distanceFromCenter > 0.95) {
        // Transparent pixel in the corners
        pixels.addAll([0, 0, 0, 0]);
      } else {
        // Solid pixel with gradient
        pixels.addAll([r, g, b, 255]);
      }
    }
  }
  
  return pixels;
}

// Generate a transparent background with the S for adaptive icon foreground
List<int> generateForegroundPixelData(int width, int height) {
  final List<int> pixels = [];
  
  // PNG header
  pixels.addAll([137, 80, 78, 71, 13, 10, 26, 10]);
  
  // Create transparent background with white S
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Center S letter
      if (_isPartOfSLetter(x, y, width, height)) {
        // White S
        pixels.addAll([255, 255, 255, 255]);
      } else {
        // Transparent
        pixels.addAll([0, 0, 0, 0]);
      }
    }
  }
  
  return pixels;
}

// Helper function to check if a pixel is part of an S letter
bool _isPartOfSLetter(int x, int y, int width, int height) {
  final centerX = width / 2;
  final centerY = height / 2;
  
  // Very simple S shape
  final double normalizedX = (x - centerX) / (width / 4);
  final double normalizedY = (y - centerY) / (height / 4);
  
  // Simplified S-curve check
  return (normalizedY > -1 && normalizedY < 1) && 
         (normalizedX > -1 && normalizedX < 1) &&
         ((normalizedY > 0 && normalizedX < 0) || 
          (normalizedY < 0 && normalizedX > 0));
}

// Calculate distance from center (0.0 to 1.0+)
double _distanceFromCenter(int x, int y, int width, int height) {
  final centerX = width / 2;
  final centerY = height / 2;
  final dx = (x - centerX) / (width / 2);
  final dy = (y - centerY) / (height / 2);
  return dx * dx + dy * dy;
} 