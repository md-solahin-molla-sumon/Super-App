
import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final selectedMode = controller.themeMode;
          final colors = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your Nexaura experience.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              Card(
                child: RadioGroup<ThemeMode>(
                  groupValue: selectedMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      controller.setThemeMode(value);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text('Light Mode'),
                        subtitle: Text('Use a bright appearance'),
                        secondary: Icon(Icons.light_mode),
                      ),
                      Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text('Dark Mode'),
                        subtitle: Text('Use a dark appearance'),
                        secondary: Icon(Icons.dark_mode),
                      ),
                      Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text('System Default'),
                        subtitle: Text('Follow your device settings'),
                        secondary: Icon(Icons.settings_brightness),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Card(
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Nexaura Theme'),
                  subtitle: Text(
                    'Personalize your app experience',
                  ),
                  trailing: Icon(Icons.check_circle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
