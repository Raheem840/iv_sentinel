import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/bed_config.dart';
import 'core/services/alert_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/bed_config_notifier.dart';
import 'features/settings/settings_screen.dart';
import 'features/detail/bed_detail_screen.dart';

// Global navigator key so AlertService tap handler can push routes from outside the widget tree
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init AlertService and start listening for notification taps
  await AlertService.instance.init();

  runApp(const ProviderScope(child: IvSentinelApp()));
}

class IvSentinelApp extends ConsumerStatefulWidget {
  const IvSentinelApp({super.key});

  @override
  ConsumerState<IvSentinelApp> createState() => _IvSentinelAppState();
}

class _IvSentinelAppState extends ConsumerState<IvSentinelApp> {
  @override
  void initState() {
    super.initState();

    // When a notification is tapped, find the matching bed and open its detail screen
    AlertService.instance.notificationTaps.listen((bedConfigId) {
      final beds = ref.read(appSettingsProvider).beds;
      final bed = beds.cast<BedConfig?>().firstWhere(
            (b) => b?.id == bedConfigId,
            orElse: () => null,
          );
      if (bed != null) {
        navigatorKey.currentState?.pushNamed('/detail', arguments: bed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(appSettingsProvider.select((s) => s.darkMode));

    return MaterialApp(
      title: 'IV Sentinel',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
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
