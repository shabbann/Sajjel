// controllers/theme_controller.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _colorSchemeIndex = 0;
  bool _isLoading = false;
  
  // Public getters
  ThemeMode get themeMode => _themeMode;
  int get colorSchemeIndex => _colorSchemeIndex;
  bool get isLoading => _isLoading;
  
  // Computed property for dark mode detection
  bool get isDarkMode => _themeMode == ThemeMode.dark || 
                         (_themeMode == ThemeMode.system && 
                          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  // Constructor
  ThemeController() {
    _initThemeSettings();
  }

  // Initialize theme settings
  Future<void> _initThemeSettings() async {
    _setLoading(true);
    try {
      await _loadThemePreferences();
    } finally {
      _setLoading(false);
    }
  }

  // Load theme preferences from storage
  Future<void> _loadThemePreferences() async {
    final savedThemeMode = await PreferencesService.getThemeMode();
    final savedColorSchemeIndex = await PreferencesService.getColorSchemeIndex() ?? 0;
    
    _themeMode = savedThemeMode;
    _colorSchemeIndex = savedColorSchemeIndex;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set theme mode with auto-save
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await PreferencesService.saveThemeMode(mode);
    notifyListeners();
  }

  // Set color scheme index with auto-save
  Future<void> setColorSchemeIndex(int index) async {
    if (_colorSchemeIndex == index) return;
    
    _colorSchemeIndex = index;
    await PreferencesService.saveColorSchemeIndex(index);
    notifyListeners();
  }

  // Toggle between light and dark theme
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // Get ThemeData based on current settings
  ThemeData getTheme() {
    if (isDarkMode) {
      return AppTheme.getDarkTheme();
    } else {
      return AppTheme.getLightTheme();
    }
  }
  
  // Reload theme preferences from storage
  Future<void> refreshThemeSettings() async {
    await _loadThemePreferences();
  }
}