import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/models/bed_config.dart';
import 'core/providers/bed_readings_provider.dart';
import 'core/services/alert_service.dart';
import 'core/services/background_alert_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/bed_config_notifier.dart';
import 'features/settings/settings_screen.dart';
import 'features/detail/bed_detail_screen.dart';
import 'features/splash/splash_screen.dart';

// Global key lets AlertService navigate from outside the widget tree
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundAlertService.instance.configure();
  runApp(const ProviderScope(child: IvSentinelApp()));
}

class IvSentinelApp extends ConsumerStatefulWidget {
  const IvSentinelApp({super.key});

  @override
  ConsumerState<IvSentinelApp> createState() => _IvSentinelAppState();
}

class _IvSentinelAppState extends ConsumerState<IvSentinelApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel(); // prevent double-push on hot-restart
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground (fast, UI-driven) and background (foreground-service)
    // polling must never run at once — each keeps its own status-transition
    // history, so overlap would double-fire alerts. Order matters: the
    // foreground timer is stopped and its state persisted BEFORE the
    // background service starts, and the background service is confirmed
    // stopped BEFORE the foreground timer resumes.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        ref.read(bedReadingsProvider.notifier).pauseForBackground().then(
              (_) => BackgroundAlertService.instance.start(),
            );
      case AppLifecycleState.resumed:
        BackgroundAlertService.instance.stop().then(
              (_) => ref.read(bedReadingsProvider.notifier).resumeFromBackground(),
            );
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
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
        '/': (_) => const SplashScreen(nextRoute: '/home'),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final config = settings.arguments;
          // A malformed navigation (bad deep link, stale restoration replay)
          // should fall through to unknown-route handling, not crash.
          if (config is! BedConfig) return null;
          return MaterialPageRoute(
            builder: (_) => BedDetailScreen(config: config),
          );
        }
        return null;
      },
    );
  }
}
