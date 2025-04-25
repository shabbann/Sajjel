import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';

enum MapProvider {
  googleMaps,
  osmAnd,
  waze,
  mapQuest,
  hereMaps,
  defaultMap,
}

class MapLauncher {
  static final Map<MapProvider, String> _androidPackages = {
    MapProvider.googleMaps: 'com.google.android.apps.maps',
    MapProvider.osmAnd: 'net.osmand',
    MapProvider.waze: 'com.waze',
    MapProvider.mapQuest: 'com.mapquest.android.ace',
    MapProvider.hereMaps: 'com.here.app.maps',
  };

  static final Map<MapProvider, String> _iosUrlSchemes = {
    MapProvider.googleMaps: 'comgooglemaps://',
    MapProvider.osmAnd: 'osmandmaps://',
    MapProvider.waze: 'waze://',
    MapProvider.mapQuest: 'mapquest://',
    MapProvider.hereMaps: 'here-location://',
  };

  static Future<bool> openMap(double latitude, double longitude, {String? label, MapProvider provider = MapProvider.defaultMap}) async {
    try {
      if (provider == MapProvider.defaultMap) {
        return await _openDefaultMap(latitude, longitude, label: label);
      }

      // For specific providers
      if (Platform.isAndroid) {
        return await _openAndroidMap(latitude, longitude, label: label, provider: provider);
      } else if (Platform.isIOS) {
        return await _openIOSMap(latitude, longitude, label: label, provider: provider);
      } else {
        // Fallback to web URL for unsupported platforms
        return await _openWebMap(latitude, longitude, label);
      }
    } catch (e) {
      debugPrint('Error opening map: $e');
      // Fallback to default map if selected provider fails
      return await _openDefaultMap(latitude, longitude, label: label);
    }
  }

  static Future<bool> _openAndroidMap(double latitude, double longitude, {String? label, required MapProvider provider}) async {
    final packageName = _androidPackages[provider];
    if (packageName == null) {
      return await _openDefaultMap(latitude, longitude, label: label);
    }

    final isInstalled = await isMapProviderInstalled(provider);
    if (!isInstalled) {
      return await _openDefaultMap(latitude, longitude, label: label);
    }

    String uri;
    switch (provider) {
      case MapProvider.googleMaps:
        uri = 'geo:$latitude,$longitude?q=$latitude,$longitude${label != null ? '($label)' : ''}';
        break;
      case MapProvider.osmAnd:
        uri = 'osmand.geo:$latitude,$longitude?z=16&name=${label ?? 'Location'}';
        break;
      case MapProvider.waze:
        uri = 'waze://?ll=$latitude,$longitude&navigate=yes';
        break;
      case MapProvider.mapQuest:
        uri = 'mq://route?from=Current%20Location&to=$latitude,$longitude';
        break;
      case MapProvider.hereMaps:
        uri = 'here-location://$latitude,$longitude';
        break;
      default:
        return await _openDefaultMap(latitude, longitude, label: label);
    }

    final uriToLaunch = Uri.parse(uri);
    final canLaunch = await canLaunchUrl(uriToLaunch);
    
    if (canLaunch) {
      return await launchUrl(uriToLaunch);
    } else {
      return await _openDefaultMap(latitude, longitude, label: label);
    }
  }

  static Future<bool> _openIOSMap(double latitude, double longitude, {String? label, required MapProvider provider}) async {
    final urlScheme = _iosUrlSchemes[provider];
    if (urlScheme == null) {
      return await _openDefaultMap(latitude, longitude, label: label);
    }

    String uri;
    switch (provider) {
      case MapProvider.googleMaps:
        uri = 'comgooglemaps://?q=$latitude,$longitude&center=$latitude,$longitude';
        break;
      case MapProvider.osmAnd:
        uri = 'osmandmaps://navigate?lat=$latitude&lon=$longitude&z=16&title=${label ?? 'Location'}';
        break;
      case MapProvider.waze:
        uri = 'waze://?ll=$latitude,$longitude&navigate=yes';
        break;
      case MapProvider.mapQuest:
        uri = 'mapquest://directions?center=$latitude,$longitude';
        break;
      case MapProvider.hereMaps:
        uri = 'here-location://$latitude,$longitude';
        break;
      default:
        return await _openDefaultMap(latitude, longitude, label: label);
    }

    final uriToLaunch = Uri.parse(uri);
    final canLaunch = await canLaunchUrl(uriToLaunch);
    
    if (canLaunch) {
      return await launchUrl(uriToLaunch);
    } else {
      return await _openDefaultMap(latitude, longitude, label: label);
    }
  }

  static Future<bool> _openDefaultMap(double latitude, double longitude, {String? label}) async {
    // Use system default maps
    if (Platform.isAndroid) {
      final uri = 'geo:$latitude,$longitude?q=$latitude,$longitude${label != null ? '($label)' : ''}';
      final uriToLaunch = Uri.parse(uri);
      final canLaunch = await canLaunchUrl(uriToLaunch);
      
      if (canLaunch) {
        return await launchUrl(uriToLaunch);
      } else {
        return await _openWebMap(latitude, longitude, label);
      }
    } else if (Platform.isIOS) {
      final uri = 'maps://?q=${label ?? 'Location'}&ll=$latitude,$longitude';
      final uriToLaunch = Uri.parse(uri);
      final canLaunch = await canLaunchUrl(uriToLaunch);
      
      if (canLaunch) {
        return await launchUrl(uriToLaunch);
      } else {
        return await _openWebMap(latitude, longitude, label);
      }
    } else {
      // Web or other platforms
      return await _openWebMap(latitude, longitude, label);
    }
  }

  static Future<bool> _openWebMap(double latitude, double longitude, String? label) async {
    final uri = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${label != null ? '&query_place_id=' + label : ''}';
    final uriToLaunch = Uri.parse(uri);
    return await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
  }

  // Check if a specific map provider is installed
  static Future<bool> isMapProviderInstalled(MapProvider provider) async {
    try {
      if (Platform.isAndroid) {
        final packageName = _androidPackages[provider];
        if (packageName == null) return false;
        
        // Since device_apps is no longer available, we'll try launching the app's URI scheme
        // If it doesn't work, we'll assume the app is not installed
        final intent = Uri.parse('android-app://$packageName');
        return await canLaunchUrl(intent);
      } else if (Platform.isIOS) {
        // For iOS, we can only try to launch the URL scheme
        final urlScheme = _iosUrlSchemes[provider];
        if (urlScheme == null) return false;
        
        return await canLaunchUrl(Uri.parse(urlScheme));
      }
    } catch (e) {
      debugPrint('Error checking if map provider is installed: $e');
      return false;
    }
    
    return false;
  }

  // Legacy method for backward compatibility 
  static Future<bool> isGoogleMapsInstalled() async {
    return isMapProviderInstalled(MapProvider.googleMaps);
  }

  // Get a list of available map providers on the device
  static Future<List<MapProvider>> getAvailableMaps() async {
    // Without device_apps, it's harder to determine available maps
    // For now, we'll just return the default map provider to ensure functionality
    // In a production app, you'd want to implement a more robust solution
    return [MapProvider.defaultMap];
  }
} 