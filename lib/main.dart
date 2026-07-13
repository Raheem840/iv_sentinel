import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/bed_config.dart';
import 'core/services/alert_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/bed_config_notifier.dart';
import 'features/settings/settings_screen.dart';
import 'features/detail/bed_detail_screen.dart';

// Global key lets AlertService navigate from outside the widget tree
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.instance.init();
  runApp(const ProviderScope(child: IvSentinelApp()));
}

class IvSentinelApp extends ConsumerStatefulWidget {
  const IvSentinelApp({super.key});

  @override
  ConsumerState<IvSentinelApp> createState() => _IvSentinelAppState();
}

class _IvSentinelAppState extends ConsumerState<IvSentinelApp> {
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();

    // Handle notification taps that arrive while the app is running
    _tapSub = AlertService.instance.notificationTaps.listen(_navigateToBed);

    // Handle cold-launch taps: fired during init() before any listener existed.
    // addPostFrameCallback ensures the navigator is mounted before we push.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = AlertService.instance.consumePendingTap();
      if (pending != null) _navigateToBed(pending);
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel(); // prevent double-push on hot-restart
    super.dispose();
  }

  void _navigateToBed(String bedConfigId) {
    final beds = ref.read(appSettingsProvider).beds;
    final bed = beds.cast<BedConfig?>().firstWhere(
          (b) => b?.id == bedConfigId,
          orElse: () => null,
        );
    if (bed == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // If the user is already on this bed's detail screen, don't push again.
    // popUntil + push ensures we always land on exactly one detail screen.
    nav.popUntil((route) => route.isFirst || route.settings.name == '/');
    nav.pushNamed('/detail', arguments: bed);
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
