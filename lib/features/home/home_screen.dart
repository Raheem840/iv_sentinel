import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/bed_readings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_loading_overlay.dart';
import '../../features/settings/bed_config_notifier.dart';
import 'widgets/bed_card.dart';
import 'widgets/critical_banner.dart';

// Keeps a rolling buffer of the last 20 readings per bed for sparklines.
// Stored here (not in Riverpod) because it's purely a display concern.
final _historyBuffer = <String, List<double>>{};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final readingsAsync = ref.watch(bedReadingsProvider);

    // Prune history for beds that have been removed from settings
    final activeBedIds = settings.beds.map((b) => b.id).toSet();
    _historyBuffer.removeWhere((id, _) => !activeBedIds.contains(id));

    // Update the sparkline history buffer whenever new data arrives
    readingsAsync.whenData((readings) {
      for (final entry in readings.entries) {
        final buf = _historyBuffer.putIfAbsent(entry.key, () => []);
        buf.add(entry.value.percent);
        if (buf.length > 20) buf.removeAt(0); // keep last 20 only
      }
    });

    // Count critical beds for the AppBar badge
    final criticalCount =
        readingsAsync
            .whenData(
              (readings) => settings.beds
                  .where((b) => readings[b.id]?.isCritical == true)
                  .length,
            )
            .value ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(criticalCount: criticalCount),
        actions: [
          // Manual refresh button
          readingsAsync.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh now',
                  onPressed: () =>
                      ref.read(bedReadingsProvider.notifier).refresh(),
                ),
          // Settings navigation
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: PulseLoadingOverlay(
        isLoading: readingsAsync.isLoading,
        child: readingsAsync.when(
          // ── Loading state (first fetch only) ──
          loading: () => _LoadingGrid(count: settings.beds.length),

          // ── Error state ──
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(bedReadingsProvider.notifier).refresh(),
          ),

          // ── Data state ──
          data: (readings) {
            if (settings.beds.isEmpty) return const _EmptyState();

            // Identify beds currently in CRITICAL for the banner
            final criticalBeds = settings.beds
                .where((b) => readings[b.id]?.isCritical == true)
                .toList();

            return RefreshIndicator(
              onRefresh: () => ref.read(bedReadingsProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: [
                  // Sticky critical alert banner (hidden when no beds are critical)
                  SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: CriticalBanner(
                        criticalBeds: criticalBeds,
                        readings: readings,
                        onTap: (config) => Navigator.pushNamed(
                          context,
                          '/detail',
                          arguments: config,
                        ),
                      ),
                    ),
                  ),
                  // Bed grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio:
                                0.80, // taller cards for the gauge
                          ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final config = settings.beds[i];
                        return BedCard(
                          config: config,
                          reading: readings[config.id],
                          history: List.of(_historyBuffer[config.id] ?? []),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/detail',
                            arguments: config,
                          ),
                        );
                      }, childCount: settings.beds.length),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── AppBar title with animated critical badge ─────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  final int criticalCount;
  const _AppBarTitle({required this.criticalCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('IV Sentinel'),
        if (criticalCount > 0) ...[
          const SizedBox(width: 8),
          // Animated badge that appears when any bed is CRITICAL
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(criticalCount),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kStatusRed,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$criticalCount CRIT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Empty state: no beds configured yet ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 64,
              color: kTextSecondaryDark,
            ),
            const SizedBox(height: 24),
            Text(
              'No beds configured',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Go to Settings and add your first bed to start monitoring.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.add),
              label: const Text('Add a Bed'),
              style: FilledButton.styleFrom(
                backgroundColor: kStatusGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton grid shown during first load ─────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  final int count;
  const _LoadingGrid({required this.count});

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 0
        ? count
        : 4; // show 4 skeletons if no beds yet
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: displayCount,
      itemBuilder: (context, i) => _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFF1C2128),
            const Color(0xFF2D333B),
            _shimmer.value,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: kStatusAmber),
            const SizedBox(height: 16),
            Text(
              'Could not reach ThingSpeak',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(backgroundColor: kStatusAmber),
            ),
          ],
        ),
      ),
    );
  }
}
