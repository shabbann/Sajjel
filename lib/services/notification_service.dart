import 'package:flutter/material.dart';

/// A temporary replacement for flutter_local_notifications
/// This provides stub methods that won't crash the app
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._();
  
  /// Initialize notification service
  Future<void> init() async {
    debugPrint('Notifications are temporarily disabled');
  }
  
  /// Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    debugPrint('Notification scheduling is temporarily disabled');
    debugPrint('Would schedule notification: $title at $scheduledDate');
  }
  
  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    debugPrint('Notification cancellation is temporarily disabled');
    debugPrint('Would cancel notification with ID: $id');
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    debugPrint('Notification cancellation is temporarily disabled');
    debugPrint('Would cancel all notifications');
  }
} 