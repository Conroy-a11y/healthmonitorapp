import 'package:flutter/material.dart';
import 'package:vitality/models/health_reading.dart';
import 'package:vitality/models/user.dart';
import 'package:vitality/services/auth_service.dart';
import 'package:vitality/services/health_reading_service.dart';
import 'package:vitality/theme.dart';
import 'package:vitality/widgets/metric_card.dart';
import 'package:vitality/widgets/reading_list_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final HealthReadingService _readingService = HealthReadingService();

  User? _user;
  List<HealthReading> _recentReadings = [];
  Map<ReadingType, HealthReading> _latestByType = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = await _authService.getCurrentUser();
    final readings = await _readingService.getReadings();

    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final latestByType = <ReadingType, HealthReading>{};
    for (final reading in readings) {
      if (!latestByType.containsKey(reading.type)) {
        latestByType[reading.type] = reading;
      }
    }

    setState(() {
      _user = user;
      _recentReadings = readings.take(5).toList();
      _latestByType = latestByType;
      _isLoading = false;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: context.textStyles.titleSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _user?.name ?? 'User',
                          style: context.textStyles.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: AppSpacing.horizontalLg,
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Latest Readings',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                  if (_latestByType.isEmpty)
                    SliverPadding(
                      padding: AppSpacing.horizontalLg,
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: AppSpacing.paddingXl,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No readings yet',
                                style: context.textStyles.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Tap + to add your first reading',
                                style: context.textStyles.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: AppSpacing.horizontalLg,
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entries = _latestByType.entries.toList();
                            final entry = entries[index];
                            return MetricCard(
                              type: entry.key,
                              value: entry.value.value,
                              unit: entry.value.unit,
                            );
                          },
                          childCount: _latestByType.length,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: AppSpacing.horizontalLg,
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Activity',
                                style: context.textStyles.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                  if (_recentReadings.isEmpty)
                    SliverPadding(
                      padding: AppSpacing.horizontalLg,
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'No recent activity',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: AppSpacing.horizontalLg,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reading = _recentReadings[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              child: ReadingListItem(
                                reading: reading,
                                onDelete: () async {
                                  await _readingService
                                      .deleteReading(reading.id);
                                  _loadData();
                                },
                              ),
                            );
                          },
                          childCount: _recentReadings.length,
                        ),
                      ),
                    ),
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 100),
                  ),
                ],
              ),
            ),
    );
  }
}
