import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

// This is a simple script to generate app icons without requiring Flutter
// Run with: dart lib/simple_icon_generator.dart

void main() async {
  print('Generating app icons...');
  
  // Create directory if it doesn't exist
  final directory = Directory('assets/icons');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  
  // Generate main icon
  await generateIcon(1024, '${directory.path}/app_icon.png');
  print('Generated main app icon');
  
  // Generate foreground icon
  await generateForegroundIcon(1024, '${directory.path}/foreground.png');
  print('Generated foreground icon');
  
  // Generate various sizes for web/desktop
  final List<int> sizes = [16, 32, 64, 128, 256, 512];
  for (final size in sizes) {
    await generateIcon(size, '${directory.path}/icon_$size.png');
    print('Generated icon with size $size');
  }
  
  print('Icon generation complete!');
}

Future<void> generateIcon(int size, String outputPath) async {
  // Create a basic PNG with dark blue-gray gradient and a white "S"
  final bytes = createGradientIconPng(size, size);
  
  // Save the PNG file
  final file = File(outputPath);
  await file.writeAsBytes(bytes);
}

Future<void> generateForegroundIcon(int size, String outputPath) async {
  // Create just the white "S" with transparent background
  final bytes = createForegroundIconPng(size, size);
  
  // Save the PNG file
  final file = File(outputPath);
  await file.writeAsBytes(bytes);
}

Uint8List createGradientIconPng(int width, int height) {
  // Create a very simple PNG file with a gradient background and a white "S"
  // This is a very basic implementation - in a real app you'd use proper image libraries
  
  final BytesBuilder builder = BytesBuilder();
  
  // PNG signature
  builder.add([137, 80, 78, 71, 13, 10, 26, 10]);
  
  // IHDR chunk
  final ihdrChunk = [
    0, 0, 0, 13,  // Length
    73, 72, 68, 82,  // 'IHDR'
    (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF, width & 0xFF,  // Width
    (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF, height & 0xFF,  // Height
    8,  // Bit depth
    6,  // Color type (RGBA)
    0,  // Compression method
    0,  // Filter method
    0,  // Interlace method
  ];
  builder.add(ihdrChunk);
  
  // CRC for IHDR chunk (pre-calculated)
  builder.add([0, 0, 0, 0]);  // Placeholder CRC
  
  // IDAT chunk - this would be the image data
  // In a real implementation, you'd generate proper PNG data with compression
  // For now, we'll just create a simple colored square with an S
  final List<int> pixelData = [];
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Create a dark blue to gray gradient
      final double normalizedX = x / width;
      final double normalizedY = y / height;
      
      // Gradient colors
      final int r = (74 + normalizedX * 10).round();
      final int g = (101 + normalizedY * 10).round();
      final int b = (114 + (normalizedX + normalizedY) * 10).round();
      
      // Is this pixel part of the "S" letter?
      if (isPartOfLetter(x, y, width, height)) {
        // White for the S
        pixelData.add(255);  // R
        pixelData.add(255);  // G
        pixelData.add(255);  // B
        pixelData.add(255);  // A
      } else {
        // Background color
        pixelData.add(r);    // R
        pixelData.add(g);    // G
        pixelData.add(b);    // B
        pixelData.add(255);  // A
      }
    }
  }
  
  // Simplified IDAT chunk (not real compression)
  final idatHeader = [
    0, 0, 0, 0,  // Length placeholder
    73, 68, 65, 84,  // 'IDAT'
  ];
  builder.add(idatHeader);
  builder.add(pixelData);
  
  // IEND chunk
  final iendChunk = [
    0, 0, 0, 0,  // Length
    73, 69, 78, 68,  // 'IEND'
    174, 66, 96, 130  // CRC
  ];
  builder.add(iendChunk);
  
  return builder.toBytes();
}

Uint8List createForegroundIconPng(int width, int height) {
  // Create just the white "S" with transparent background
  final BytesBuilder builder = BytesBuilder();
  
  // PNG signature
  builder.add([137, 80, 78, 71, 13, 10, 26, 10]);
  
  // IHDR chunk
  final ihdrChunk = [
    0, 0, 0, 13,  // Length
    73, 72, 68, 82,  // 'IHDR'
    (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF, width & 0xFF,  // Width
    (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF, height & 0xFF,  // Height
    8,  // Bit depth
    6,  // Color type (RGBA)
    0,  // Compression method
    0,  // Filter method
    0,  // Interlace method
  ];
  builder.add(ihdrChunk);
  
  // CRC for IHDR chunk (pre-calculated)
  builder.add([0, 0, 0, 0]);  // Placeholder CRC
  
  // IDAT chunk - this would be the image data
  final List<int> pixelData = [];
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // Is this pixel part of the "S" letter?
      if (isPartOfLetter(x, y, width, height)) {
        // White for the S
        pixelData.add(255);  // R
        pixelData.add(255);  // G
        pixelData.add(255);  // B
        pixelData.add(255);  // A
      } else {
        // Transparent background
        pixelData.add(0);    // R
        pixelData.add(0);    // G
        pixelData.add(0);    // B
        pixelData.add(0);    // A
      }
    }
  }
  
  // Simplified IDAT chunk
  final idatHeader = [
    0, 0, 0, 0,  // Length placeholder
    73, 68, 65, 84,  // 'IDAT'
  ];
  builder.add(idatHeader);
  builder.add(pixelData);
  
  // IEND chunk
  final iendChunk = [
    0, 0, 0, 0,  // Length
    73, 69, 78, 68,  // 'IEND'
    174, 66, 96, 130  // CRC
  ];
  builder.add(iendChunk);
  
  return builder.toBytes();
}

bool isPartOfLetter(int x, int y, int width, int height) {
  // Create a stylized "S" shape
  final double centerX = width / 2;
  final double centerY = height / 2;
  
  // Normalize coordinates to be between -1 and 1
  final double nx = (x - centerX) / (width / 3);
  final double ny = (y - centerY) / (height / 3);
  
  // Simple S-curve equation
  final double distance = math.sqrt(nx * nx + ny * ny);
  
  // Basic S shape (this is a very simplified approach)
  if (distance > 0.8 || distance < 0.3) return false;
  
  // Top half of S
  if (ny < 0 && nx < 0) return false;
  
  // Bottom half of S
  if (ny > 0 && nx > 0) return false;
  
  return true;
} 