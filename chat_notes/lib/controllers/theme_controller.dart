// controllers/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'package:chat_notes/services/preferences_service.dart';

class ThemeController extends ChangeNotifier {
  static const String _themeKey = 'themeMode';
  static const String _colorKey = 'colorScheme';
  
  int _colorSchemeIndex = 0;
  late ThemeMode _themeMode;
  bool _isLoaded = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark || 
      (_themeMode == ThemeMode.system && 
       WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
  int get colorSchemeIndex => _colorSchemeIndex;

  // Color schemes with predefined colors
  final List<ColorScheme> colorSchemes = [
    // Blue
    const ColorScheme.light(
      primary: Color(0xFF3F51B5),
      secondary: Color(0xFF2196F3),
      tertiary: Color(0xFF00BCD4),
    ),
    // Green
    const ColorScheme.light(
      primary: Color(0xFF4CAF50),
      secondary: Color(0xFF8BC34A),
      tertiary: Color(0xFFCDDC39),
    ),
    // Purple
    const ColorScheme.light(
      primary: Color(0xFF673AB7),
      secondary: Color(0xFF9C27B0),
      tertiary: Color(0xFFE91E63),
    ),
    // Orange
    const ColorScheme.light(
      primary: Color(0xFFFF9800),
      secondary: Color(0xFFFF5722),
      tertiary: Color(0xFFF44336),
    ),
  ];

  ThemeController() {
    loadThemeMode();
  }

  Future<void> loadThemeMode() async {
    _themeMode = await PreferencesService.getThemeMode();
    _isLoaded = true;
    _loadThemePreference();
    notifyListeners();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    
    _colorSchemeIndex = prefs.getInt(_colorKey) ?? 0;
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _themeMode.index);
    await prefs.setInt(_colorKey, _colorSchemeIndex);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await PreferencesService.saveThemeMode(mode);
    _saveThemePreference();
    notifyListeners();
  }

  void setColorSchemeIndex(int index) {
    if (index >= 0 && index < colorSchemes.length) {
      _colorSchemeIndex = index;
      _saveThemePreference();
      notifyListeners();
    }
  }

  ThemeData getTheme() {
    // Start with the base theme from AppTheme
    final baseTheme = isDarkMode 
        ? AppTheme.getDarkTheme() 
        : AppTheme.getLightTheme();
    
    // Apply the selected color scheme
    return baseTheme.copyWith(
      colorScheme: isDarkMode
          ? colorSchemes[_colorSchemeIndex].copyWith(brightness: Brightness.dark)
          : colorSchemes[_colorSchemeIndex],
      primaryColor: colorSchemes[_colorSchemeIndex].primary,
      appBarTheme: AppBarTheme(
        backgroundColor: colorSchemes[_colorSchemeIndex].primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorSchemes[_colorSchemeIndex].primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  bool get isLoaded => _isLoaded;

  Future<void> toggleThemeMode() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }

  // Light theme colors
  static final lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4CAF50),
    brightness: Brightness.light,
  );

  // Dark theme colors
  static final darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4CAF50),
    brightness: Brightness.dark,
  );

  // Add method to toggle theme
  Future<void> toggleTheme() async {
    await toggleThemeMode();
  }
}