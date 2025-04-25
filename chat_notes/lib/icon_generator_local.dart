import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';

// This script generates app icons for Flutter apps
// Run with: flutter run -t lib/icon_generator_local.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await generateIcons();
  print('Icon generation complete. Icons saved to assets/icons directory.');
  exit(0);
}

Future<void> generateIcons() async {
  final directory = Directory('assets/icons');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  
  // Generate the main app icon
  await _generateIcon(1024, '${directory.path}/app_icon.png');
  print('Generated main app icon');
  
  // Generate the foreground icon (same as main for simplicity)
  await _generateIcon(1024, '${directory.path}/foreground.png', drawBackground: false);
  print('Generated foreground icon');
  
  // Generate various sizes for web/desktop
  final List<int> sizes = [16, 32, 64, 128, 256, 512];
  for (final size in sizes) {
    await _generateIcon(size, '${directory.path}/icon_$size.png');
    print('Generated icon with size $size');
  }
}

Future<void> _generateIcon(int size, String outputPath, {bool drawBackground = true}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Create a square canvas
  final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  
  if (drawBackground) {
    // Draw background with gradient
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.toDouble(), size.toDouble()),
        [Color(0xFF4A6572), Color(0xFF232F34)],
      )
      ..style = PaintingStyle.fill;
    
    // Draw rounded rectangle background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.2)),
      paint,
    );
  }
  
  // Draw a stylized "S" for Sajjel
  final textPainter = TextPainter(
    text: TextSpan(
      text: 'S',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.6,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    ),
  );
  
  // Convert to an image
  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  
  // Save to file
  final file = File(outputPath);
  await file.writeAsBytes(pngBytes!.buffer.asUint8List());
} 