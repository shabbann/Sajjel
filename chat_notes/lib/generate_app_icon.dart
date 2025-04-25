import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// This is a simple script to generate app icons with a gradient background and a stylized "S"
// Run with: flutter run -t lib/generate_app_icon.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final outputDir = await generateAppIcon();
  print('Icon generation complete. Check the directory: $outputDir');
  exit(0);
}

Future<String> generateAppIcon() async {
  // Use the application documents directory which is writable
  final appDir = await getApplicationDocumentsDirectory();
  final directory = Directory('${appDir.path}/app_icons');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  
  // Define the icon sizes we want to generate
  final List<int> sizes = [16, 32, 64, 128, 256, 512, 1024];
  
  for (final size in sizes) {
    await _generateIcon(size, '${directory.path}/icon_$size.png');
    print('Generated icon with size $size');
  }
  
  return directory.path;
}

Future<void> _generateIcon(int size, String outputPath) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // Create a square canvas
  final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  
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
  
  // Draw a simple note icon (just a stylized "S" in this case)
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