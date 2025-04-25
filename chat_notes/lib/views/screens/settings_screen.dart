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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThemeSection(context),
          const Divider(),
          _buildChatSettings(context),
          const Divider(),
          if (_isLocationSupported) ...[
            _buildLocationSection(context),
            const Divider(),
          ],
          _buildDataSection(context),
          const Divider(),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
            ),
          ],
          selected: {themeController.themeMode},
          onSelectionChanged: (Set<ThemeMode> selected) {
            themeController.setThemeMode(selected.first);
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Color Scheme',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(4, (index) {
            final colorScheme = themeController.colorSchemes[index % themeController.colorSchemes.length];
            return InkWell(
              onTap: () => themeController.setColorSchemeIndex(index),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeController.colorSchemeIndex == index
                        ? colorScheme.secondary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildChatSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chat Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FutureBuilder<String?>(
          future: PreferencesService.getDefaultChat(),
          builder: (context, snapshot) {
            final hasDefaultChat = snapshot.data != null;
            
            return ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Default Chat'),
              subtitle: Text(
                hasDefaultChat 
                    ? 'A default chat is set' 
                    : 'No default chat set (will open last viewed)'
              ),
              trailing: hasDefaultChat ? 
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () async {
                    await PreferencesService.saveDefaultChat(null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Default chat cleared')),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ) : null,
            );
          },
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Set Default Chat'),
          subtitle: Text(
            'Long-press any chat in the chat list to set or remove it as the default'
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Current Location'),
          subtitle: FutureBuilder<String?>(
            future: LocationService.getLocationAddress(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Getting location...');
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              return Text(snapshot.data ?? 'Location not available');
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Location History'),
          subtitle: FutureBuilder<List<Position>>(
            future: LocationService.getLocationHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Loading history...');
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              final history = snapshot.data ?? [];
              return Text('${history.length} locations recorded');
            },
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await LocationService.clearLocationHistory();
              (context as Element).markNeedsBuild();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('Backup Data'),
          onTap: () => _backupData(context),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore Data'),
          onTap: () => _restoreData(context),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Sajjel'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Sajjel',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2024 Sajjel',
              children: [
                const Text(
                  'A modern note-taking app with location features and beautiful themes.',
                  textAlign: TextAlign.center,
                ),
                if (!_isLocationSupported) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Note: Location features are not available on this platform.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}