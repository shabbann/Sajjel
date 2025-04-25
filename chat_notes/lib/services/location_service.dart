import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationService {
  static const String _lastLocationKey = 'last_location';
  static const String _locationHistoryKey = 'location_history';
  static const int _maxHistoryItems = 10;

  static bool get isLocationSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<bool> checkLocationPermission() async {
    if (!isLocationSupported) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    if (!isLocationSupported) {
      // Return a mock position for Windows/Web
      return Position(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    try {
      if (!await checkLocationPermission()) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _saveLocation(position);
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<String?> getLocationAddress() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      if (!isLocationSupported) {
        return 'Location services not available on this platform';
      }

      // Here you would typically use a geocoding service to get the address
      // For now, we'll just return the coordinates
      return '${position.latitude}, ${position.longitude}';
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  static Future<void> _saveLocation(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save last location
    await prefs.setString(_lastLocationKey, 
      '${position.latitude},${position.longitude},${position.timestamp.toIso8601String()}');
    
    // Update location history
    final history = prefs.getStringList(_locationHistoryKey) ?? [];
    final newEntry = '${position.latitude},${position.longitude},${position.timestamp.toIso8601String()}';
    
    if (!history.contains(newEntry)) {
      history.insert(0, newEntry);
      if (history.length > _maxHistoryItems) {
        history.removeLast();
      }
      await prefs.setStringList(_locationHistoryKey, history);
    }
  }

  static Future<List<Position>> getLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_locationHistoryKey) ?? [];
    
    return history.map((entry) {
      final parts = entry.split(',');
      return Position(
        latitude: double.parse(parts[0]),
        longitude: double.parse(parts[1]),
        timestamp: DateTime.parse(parts[2]),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }).toList();
  }

  static Future<Position?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLocation = prefs.getString(_lastLocationKey);
    
    if (lastLocation == null) return null;
    
    final parts = lastLocation.split(',');
    return Position(
      latitude: double.parse(parts[0]),
      longitude: double.parse(parts[1]),
      timestamp: DateTime.parse(parts[2]),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  static Future<void> clearLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationHistoryKey);
    await prefs.remove(_lastLocationKey);
  }
} 