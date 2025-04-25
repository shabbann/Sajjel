import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static const String _lastLocationKey = 'last_location';
  static const String _locationHistoryKey = 'location_history';
  static const int _maxHistoryItems = 10;
  
  // Flag to track if initialization was completed
  static bool _initialized = false;
  
  // Lazy initialization
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    
    // Perform minimal initialization, defer permissions request
    // until actually needed
    _initialized = true;
  }

  static bool get isLocationSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<bool> checkLocationPermission() async {
    if (!isLocationSupported) return false;

    try {
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
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  static Future<Position?> getCurrentLocation() async {
    // Ensure the service is initialized
    await ensureInitialized();
    
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
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    try {
      if (!await checkLocationPermission()) {
        return null;
      }
      
      // Use low accuracy for faster results
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      
      // Save location in the background without awaiting
      _saveLocation(position);
      
      return position;
    } catch (e) {
      debugPrint('Error getting location: $e');
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
        altitudeAccuracy: 0,
        headingAccuracy: 0,
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
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  static Future<void> clearLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationHistoryKey);
    await prefs.remove(_lastLocationKey);
  }

  static Future<bool> openLocationInMap(double latitude, double longitude, {String? label}) async {
    try {
      print('Trying to open maps with coordinates: $latitude, $longitude');
      
      // Most basic approach for Android using the geo: schema
      final String mapUrl = "geo:0,0?q=$latitude,$longitude(${Uri.encodeComponent(label ?? 'Location')})";
      print('Using basic map URL: $mapUrl');
      
      final Uri uri = Uri.parse(mapUrl);
      
      if (await canLaunchUrl(uri)) {
        print('Launching URL: $uri');
        return await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        print('Cannot launch URL, trying direct Google Maps URL');
        // If that fails, try direct Google Maps URL as a fallback
        final String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        final Uri googleUri = Uri.parse(googleUrl);
        
        if (await canLaunchUrl(googleUri)) {
          print('Launching Google Maps web URL');
          return await launchUrl(googleUri, mode: LaunchMode.externalApplication);
        }
        
        print('All launch attempts failed');
        return false;
      }
    } catch (e) {
      print('Error in openLocationInMap: $e');
      return false;
    }
  }
} 