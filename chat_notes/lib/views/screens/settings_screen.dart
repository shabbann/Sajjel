import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/database_service.dart';
import '../../controllers/theme_controller.dart';
import '../dialogs/app_lock_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final dbService = DatabaseService();
        final success = await dbService.restoreDatabase(result.files.single.path!);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database restored successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore database')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          Consumer<ThemeController>(
            builder: (context, themeController, _) {
              return SwitchListTile(
                title: Text('Dark Mode'),
                secondary: Icon(Icons.dark_mode),
                value: themeController.isDarkMode,
                onChanged: (value) {
                  themeController.toggleTheme();
                },
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.backup),
            title: Text('Backup Data'),
            onTap: () => _backupData(context),
          ),
          ListTile(
            leading: Icon(Icons.restore),
            title: Text('Restore Data'),
            onTap: () => _restoreData(context),
          ),
          ListTile(
            leading: Icon(Icons.security),
            title: Text('App Lock'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AppLockDialog(),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sajjel',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Sajjel',
              );
            },
          ),
        ],
      ),
    );
  }
}