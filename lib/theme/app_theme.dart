import 'package:flutter/material.dart';

// Modern color schemes definition
class AppColorScheme {
  final String name;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;

  const AppColorScheme({
    required this.name,
    required this.lightScheme,
    required this.darkScheme,
  });
}

class AppTheme {
  // Strict Monochrome Color Scheme
  static final AppColorScheme monochromeScheme = AppColorScheme(
      name: 'Monochrome',
      lightScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF000000), // Black
        onPrimary: Color(0xFFFFFFFF), // White
        secondary: Color(0xFF424242), // Dark Grey
        onSecondary: Color(0xFFFFFFFF), // White
        tertiary: Color(0xFF757575), // Medium Grey
        onTertiary: Color(0xFFFFFFFF), // White
        error: Color(0xFFB00020), // Standard Material Error Red (can keep for clarity)
        onError: Color(0xFFFFFFFF),
        background: Color(0xFFFFFFFF), // White
        onBackground: Color(0xFF000000), // Black
        surface: Color(0xFFF5F5F5), // Very Light Grey
        onSurface: Color(0xFF000000), // Black
        surfaceVariant: Color(0xFFEEEEEE), // Lighter Grey
        onSurfaceVariant: Color(0xFF000000),
        outline: Color(0xFFBDBDBD), // Light Grey Border
        shadow: Color(0xFF000000), // Black
        inverseSurface: Color(0xFF303030), // Dark Grey for inverse
        onInverseSurface: Color(0xFFFFFFFF), // White
        inversePrimary: Color(0xFFFFFFFF), // White for inverse primary
        surfaceTint: Color(0xFF000000), // Black
      ),
      darkScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFFFFFFFF), // White
        onPrimary: Color(0xFF000000), // Black
        secondary: Color(0xFFBDBDBD), // Light Grey
        onSecondary: Color(0xFF000000), // Black
        tertiary: Color(0xFF9E9E9E), // Medium Grey
        onTertiary: Color(0xFF000000), // Black
        error: Color(0xFFCF6679), // Standard Material Dark Error Red
        onError: Color(0xFF000000),
        background: Color(0xFF000000), // Black
        onBackground: Color(0xFFFFFFFF), // White
        surface: Color(0xFF121212), // Very Dark Grey
        onSurface: Color(0xFFFFFFFF), // White
        surfaceVariant: Color(0xFF212121), // Darker Grey
        onSurfaceVariant: Color(0xFFFFFFFF),
        outline: Color(0xFF616161), // Medium Grey Border
        shadow: Color(0xFF000000), // Black
        inverseSurface: Color(0xFFE0E0E0), // Light Grey for inverse
        onInverseSurface: Color(0xFF000000), // Black
        inversePrimary: Color(0xFF000000), // Black for inverse primary
        surfaceTint: Color(0xFFFFFFFF), // White
      ),
    );

  // Use only the monochrome scheme
  static final List<AppColorScheme> colorSchemes = [monochromeScheme];

  // Default padding values
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;
  
  // Border radius
  static BorderRadius defaultBorderRadius = BorderRadius.circular(12.0);
  static BorderRadius largeBorderRadius = BorderRadius.circular(16.0);
  
  // Card elevation (reduced for flatter look)
  static const double defaultElevation = 0.5;
  static const double highlightedElevation = 1.0;

  // Get active color scheme (always the first/only one)
  static AppColorScheme getColorScheme([int index = 0]) { // Index ignored
    return colorSchemes[0];
  }
  
  // Get light theme with monochrome color scheme
  static ThemeData getLightTheme([int colorSchemeIndex = 0]) { // Index ignored
    final scheme = getColorScheme().lightScheme;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background, // Ensure scaffold uses background
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, // Use surface for app bar
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        elevation: highlightedElevation,
      ),
      cardTheme: CardTheme(
        elevation: defaultElevation,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
          side: BorderSide( // Add subtle border to cards
            color: scheme.outline.withOpacity(0.5),
            width: 0.5,
          )
        ),
        color: scheme.surface, // Use surface for cards
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          elevation: 0, // Flat buttons
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline), // Use outline color
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurface, // Default icons to onSurface color
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant, // Use surface variant for input fields
        border: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5), // Slightly thicker focus border
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        ),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: scheme.outline.withOpacity(0.5))
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surface, // Use surface for dialogs
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: defaultBorderRadius),
        elevation: highlightedElevation, // Slight elevation for dialogs
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface, // Use surface for nav bar
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.tertiary, // Use tertiary grey
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: scheme.primary, // Color for selected state
        selectedTileColor: scheme.primaryContainer.withOpacity(0.1), // Background for selected
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
      ),
    );
  }
  
  // Get dark theme with monochrome color scheme
  static ThemeData getDarkTheme([int colorSchemeIndex = 0]) { // Index ignored
    final scheme = getColorScheme().darkScheme;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background, // Ensure scaffold uses background
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, // Use surface for app bar
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        elevation: highlightedElevation,
      ),
      cardTheme: CardTheme(
        elevation: defaultElevation,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
          side: BorderSide( // Add subtle border to cards
            color: scheme.outline.withOpacity(0.5),
            width: 0.5,
          )
        ),
        color: scheme.surface, // Use surface for cards
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: defaultBorderRadius),
        elevation: highlightedElevation,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceVariant, // Use surface variant for popups
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: defaultBorderRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          elevation: 0, // Flat buttons
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline), // Use outline color
          shape: RoundedRectangleBorder(
            borderRadius: defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurface, // Default icons to onSurface color
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface, // Use surface for drawer
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface, // Use surface for nav bar
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.tertiary, // Use tertiary grey
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: scheme.primary,
        selectedTileColor: scheme.onSurface.withOpacity(0.08), // Subtle selection background
        textColor: scheme.onSurface,
        iconColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant, // Use surface variant for input fields
        border: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5), // Slightly thicker focus border
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        ),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: scheme.outline.withOpacity(0.5))
        ),
      ),
    );
  }
}