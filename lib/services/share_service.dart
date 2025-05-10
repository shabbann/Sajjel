import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A temporary replacement for share_plus functionality
class ShareService {
  /// Share text by copying to clipboard and showing a snackbar
  static Future<void> shareText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    
    // Show a snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// Share a file path by copying to clipboard and showing a snackbar
  static Future<void> shareFile(BuildContext context, String filePath) async {
    await Clipboard.setData(ClipboardData(text: filePath));
    
    // Show a snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
} 