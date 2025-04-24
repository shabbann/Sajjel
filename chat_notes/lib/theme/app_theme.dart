import 'package:flutter/material.dart';

class AppTheme {
  // Add this to AppTheme class
static ThemeData get darkTheme {
  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.grey[900],
    scaffoldBackgroundColor: Colors.black,
    
    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[800],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24.0),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 10.0,
      ),
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
    
    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
    ),
    
    // Chat Bubble Theme
    cardTheme: CardTheme(
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
    ),
  );
}

// Add these bubble decorations for dark mode
static BoxDecoration userBubbleDecorationDark = BoxDecoration(
  color: Colors.blue[800],
  borderRadius: BorderRadius.circular(16.0),
);

static BoxDecoration otherBubbleDecorationDark = BoxDecoration(
  color: Colors.grey[800],
  borderRadius: BorderRadius.circular(16.0),
);
  // Colors
  static const Color primaryColor = Colors.black;
  static const Color backgroundColor = Colors.white;
  static const Color accentColor = Colors.grey;
  
  // Text Styles
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: Colors.black,
  );

  static const TextStyle timestampStyle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  // Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: titleStyle,
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.grey[500]),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 10.0,
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: primaryColor,
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
        ),
      ),
      
      // Chat Bubble Theme
      cardTheme: CardTheme(
        color: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
      ),
    );
  }

  // Chat Bubble Styles
  static BoxDecoration userBubbleDecoration = BoxDecoration(
    color: primaryColor,
    borderRadius: BorderRadius.circular(16.0),
  );

  static BoxDecoration otherBubbleDecoration = BoxDecoration(
    color: Colors.grey[200],
    borderRadius: BorderRadius.circular(16.0),
  );

  static const TextStyle userBubbleTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 16.0,
  );

  static const TextStyle otherBubbleTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 16.0,
  );
}