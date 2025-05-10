import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PreferencesService {
  static const String _lastOpenedChatKey = 'last_opened_chat';
  static const String _defaultChatKey = 'default_chat';
  static const String _themeModeKey = 'theme_mode';
  static const String _themeKey = 'themeMode';
  static const String _colorSchemeKey = 'colorSchemeIndex';

  // Get the last opened chat ID
  static Future<String?> getLastOpenedChat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedChatKey);
  }

  // Save the last opened chat ID
  static Future<void> saveLastOpenedChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedChatKey, chatId);
  }

  // Get the default chat ID (if set by user)
  static Future<String?> getDefaultChat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultChatKey);
  }

  // Save the default chat ID
  static Future<void> saveDefaultChat(String? chatId) async {
    final prefs = await SharedPreferences.getInstance();
    if (chatId != null) {
      await prefs.setString(_defaultChatKey, chatId);
    } else {
      await prefs.remove(_defaultChatKey);
    }
  }

  // Determine which chat to open (default chat or last opened)
  static Future<String?> getChatToOpen() async {
    final defaultChat = await getDefaultChat();
    // If a default chat is set, use that
    if (defaultChat != null) {
      return defaultChat;
    }
    // Otherwise use the last opened chat
    return await getLastOpenedChat();
  }

  // Get the theme mode preference
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      return ThemeMode.values[themeModeIndex];
    }
    return ThemeMode.system;
  }

  // Save the theme mode preference
  static Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, themeMode.index);
  }

  // Get/save color scheme index
  static Future<int?> getColorSchemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_colorSchemeKey);
  }

  static Future<void> saveColorSchemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSchemeKey, index);
  }
} 