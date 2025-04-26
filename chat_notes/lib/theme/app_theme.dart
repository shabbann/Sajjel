import 'package:flutter/material.dart';

// Adding ThemeNotifier class that's referenced in the code
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class AppTheme {
  static const Color primaryColor = Color(0xFF3F51B5); // Indigo
  static const Color accentColor = Color(0xFF2196F3);  // Blue
  static const Color secondaryColor = Color(0xFF00BCD4); // Cyan
  static const Color lightTextColor = Color(0xFF333333);
  static const Color darkTextColor = Color(0xFFF5F5F5);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1A1A1A);
  static const Color darkDialogColor = Color(0xFF1A1A1A);
  
  // Default padding values
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;
  
  // Border radius
  static BorderRadius defaultBorderRadius = BorderRadius.circular(12.0);
  static BorderRadius largeBorderRadius = BorderRadius.circular(20.0);
  
  // Card elevation
  static const double defaultElevation = 2.0;
  static const double highlightedElevation = 4.0;
  
  // Text styles
  static TextStyle get headingTextStyle => const TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  
  static TextStyle get subheadingTextStyle => const TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle get bodyTextStyle => const TextStyle(
    fontSize: 16.0,
  );
  
  static TextStyle get captionTextStyle => const TextStyle(
    fontSize: 14.0,
    color: Colors.grey,
  );
  
  // Theme data
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryColor,
        background: Colors.white,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: defaultElevation,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      iconTheme: const IconThemeData(
        color: primaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        ),
      ),
    );
  }
  
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryColor,
        background: darkBackground,
        surface: darkSurface,
        onBackground: darkTextColor,
        onSurface: darkTextColor,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextColor,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: defaultElevation,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        color: darkCardColor,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkDialogColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: defaultBorderRadius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkCardColor,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkTextColor),
        displayMedium: TextStyle(color: darkTextColor),
        displaySmall: TextStyle(color: darkTextColor),
        headlineLarge: TextStyle(color: darkTextColor),
        headlineMedium: TextStyle(color: darkTextColor),
        headlineSmall: TextStyle(color: darkTextColor),
        titleLarge: TextStyle(color: darkTextColor),
        titleMedium: TextStyle(color: darkTextColor),
        titleSmall: TextStyle(color: darkTextColor),
        bodyLarge: TextStyle(color: darkTextColor),
        bodyMedium: TextStyle(color: darkTextColor),
        bodySmall: TextStyle(color: darkTextColor),
        labelLarge: TextStyle(color: darkTextColor),
        labelMedium: TextStyle(color: darkTextColor),
        labelSmall: TextStyle(color: darkTextColor),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkTextColor,
        iconColor: darkTextColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide(color: accentColor, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        ),
        fillColor: darkCardColor,
        filled: true,
        hintStyle: TextStyle(color: Colors.grey[400]),
        labelStyle: TextStyle(color: Colors.grey[300]),
      ),
    );
  }
}