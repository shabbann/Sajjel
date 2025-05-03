import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:file_picker/file_picker.dart'; // Removed FilePicker import
import '../../services/database_service.dart';
import '../../services/preferences_service.dart';
import '../../controllers/theme_controller.dart';
import '../dialogs/app_lock_dialog.dart';
import '../../services/location_service.dart';
import '../../services/file_service.dart'; // Added FileService import
import 'map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isLocationSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      final dbService = DatabaseService();
      final path = await dbService.backupDatabase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup created at: $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create backup: $e')),
      );
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      // Using our custom FileService instead of FilePicker
      final path = await FileService.pickImage();
      
      if (path != null) {
        final dbService = DatabaseService();
        final success = await dbService.restoreDatabase(path);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore database')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during restore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: _animationController,
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'Appearance'),
              const SizedBox(height: 16),
              
              // Theme mode selection
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0, right: 16.0),
                      child: Text(
                        'Theme Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // Use Theme.listTileTheme for consistent styling
                    _buildThemeRadioTile(themeController, theme, 'Light', ThemeMode.light),
                    _buildThemeRadioTile(themeController, theme, 'Dark', ThemeMode.dark),
                    _buildThemeRadioTile(themeController, theme, 'System', ThemeMode.system),
                    const SizedBox(height: 8), // Add padding at the bottom
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // About section
              _buildSectionTitle(context, 'About'),
              const SizedBox(height: 16),
              _buildCard(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('App Version'),
                        trailing: const Text('1.0.0'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.code,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Source Code'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () {
                          // Open source code link
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper for Theme Radio Tiles with Lighter Glow Effect
  Widget _buildThemeRadioTile(ThemeController controller, ThemeData theme, String title, ThemeMode value) {
    final bool isSelected = controller.themeMode == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.surfaceVariant 
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 1.0 : 0.5,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 4,
            spreadRadius: 0,
          )
        ] : null,
      ),
      child: RadioListTile<ThemeMode>(
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurface,
          )
        ),
        value: value,
        groupValue: controller.themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            controller.setThemeMode(newValue);
          }
        },
        activeColor: theme.colorScheme.primary,
        selected: isSelected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
  
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: Theme.of(context).cardTheme.elevation ?? 0.5,
      shape: Theme.of(context).cardTheme.shape, // Use theme shape
      color: Theme.of(context).cardTheme.color, // Use theme color
      child: child,
    );
  }

  Color _getThemeModeColor(ThemeMode themeMode, ThemeMode selectedMode, ThemeData theme) {
    if (themeMode == selectedMode) {
      return theme.colorScheme.surfaceVariant;
    } else {
      return theme.colorScheme.surface;
    }
  }

  Color _getBorderColor(ThemeMode themeMode, ThemeMode selectedMode, ThemeData theme) {
    if (themeMode == selectedMode) {
      return theme.colorScheme.primary;
    } else {
      return theme.colorScheme.outline.withOpacity(0.2);
    }
  }
}