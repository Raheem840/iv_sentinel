import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/bed_config.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/bed_config_notifier.dart';
import 'features/settings/settings_screen.dart';
import 'features/detail/bed_detail_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: IvSentinelApp()));
}

class IvSentinelApp extends ConsumerWidget {
  const IvSentinelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(appSettingsProvider.select((s) => s.darkMode));

    return MaterialApp(
      title: 'IV Sentinel',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      // Detail screen needs a BedConfig argument passed via Navigator.pushNamed
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final config = settings.arguments as BedConfig;
          return MaterialPageRoute(
            builder: (_) => BedDetailScreen(config: config),
          );
        }
        return null;
      },
    );
  }
}
