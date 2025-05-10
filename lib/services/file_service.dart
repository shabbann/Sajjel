import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A service to handle file picking and management without depending on file_picker plugin
class FileService {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery
  /// Returns the file path or null if cancelled
  static Future<String?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image?.path;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Picks an image from the camera
  /// Returns the file path or null if cancelled
  static Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      return photo?.path;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  /// Picks a video from the gallery
  /// Returns the file path or null if cancelled
  static Future<String?> pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      return video?.path;
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  /// Picks a video from the camera
  /// Returns the file path or null if cancelled
  static Future<String?> takeVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
      return video?.path;
    } catch (e) {
      debugPrint('Error taking video: $e');
      return null;
    }
  }

  /// Gets the file name from a path
  static String getFileName(String path) {
    return path.split('/').last;
  }

  /// Gets the file extension from a path
  static String getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  /// Checks if the file is an image
  static bool isImage(String path) {
    final extension = getFileExtension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp'].contains(extension);
  }

  /// Checks if the file is a video
  static bool isVideo(String path) {
    final extension = getFileExtension(path);
    return ['mp4', 'mov', '3gp', 'avi', 'mkv', 'webm'].contains(extension);
  }

  /// Gets the file size in MB
  static Future<double> getFileSize(String path) async {
    final File file = File(path);
    final int bytes = await file.length();
    return bytes / (1024 * 1024); // Convert to MB
  }
} 